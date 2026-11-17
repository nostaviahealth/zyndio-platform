import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/health_data_repository.dart';
import '../../providers/lab_reports_provider.dart';
import '../../providers/lab_analysis_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../services/gamification_service.dart';
import '../../widgets/tc025/tc025_widgets.dart';

class LabReportVerificationScreen extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;
  final String profileId;
  final Map<String, dynamic> extractedData;

  const LabReportVerificationScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.profileId,
    required this.extractedData,
  });

  @override
  ConsumerState<LabReportVerificationScreen> createState() => _LabReportVerificationScreenState();
}

class _LabReportVerificationScreenState extends ConsumerState<LabReportVerificationScreen> {
  late List<Map<String, dynamic>> _markers;
  late TextEditingController _titleController;
  late TextEditingController _dateController;
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _markers = (widget.extractedData['markers'] as List).map((m) {
      final map = Map<String, dynamic>.from(m);
      map['id'] ??= DateTime.now().microsecondsSinceEpoch.toString() + map.hashCode.toString();
      return map;
    }).toList();
    _titleController = TextEditingController(text: widget.extractedData['title']);
    _dateController = TextEditingController(text: widget.extractedData['date']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addMarker() {
    HapticFeedback.lightImpact();
    setState(() {
      _markers.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': '',
        'value': '',
        'unit': '',
        'category': 'General',
      });
    });
    
    // Smoothly scroll to the top to show the new card
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  void _removeMarker(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _markers.removeWhere((m) => m['id'] == id);
    });
  }

  Future<void> _submit() async {
    setState(() => _isUploading = true);

    final success = await HealthDataRepository.uploadLabReport(
      filePath: widget.filePath,
      fileName: widget.fileName,
      profileId: widget.profileId,
      extractedData: {
        'title': _titleController.text,
        'date': _dateController.text,
        'markers': _markers,
        'summary': 'User Verified Report. ${_markers.length} biomarkers.',
      },
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        // ─── Award Reward ───
        final referenceId = 'lab_verify_${DateTime.now().millisecondsSinceEpoch}';
        ref.read(gamificationProvider.notifier).awardReward(
          RewardType.labVerified,
          referenceId: referenceId,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report verified and uploaded successfully! 🚀')),
        );
        ref.invalidate(labReportsProvider); // Refresh the list
        
        // ✨ Success: Now we can safely clear the analysis state.
        ref.read(labAnalysisProvider.notifier).consumeResult();

        // Close the verification screen and return to the previous screen (Health Data list)
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return ZyndioDetailScaffold(
      title: 'Verify Results',
      backIcon: LucideIcons.x,
      onBack: () => context.pop(),
      trailing: _buildAddButton(c),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // Report Info Section
          _buildReportInfo(),

          const SizedBox(height: 28),

          ZyndioSectionLabel(
            'BIOMARKERS',
            trailing: Text(
              '${_markers.length} found',
              style: ZyndioType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: c.textTertiary,
              ),
            ),
          ),

          ...List.generate(_markers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EditableBiomarkerCard(
                key: ValueKey(_markers[index]['id']),
                data: _markers[index],
                onRemove: () => _removeMarker(_markers[index]['id']),
                onUpdate: (key, val) {
                  _markers[index][key] = val;
                },
              ),
            );
          }),
        ],
      ),
      bottomBar: _buildBottomAction(c),
    );
  }

  Widget _buildAddButton(ZyndioColors c) {
    return GestureDetector(
      onTap: _addMarker,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: zyndioCard(context, radius: 22, color: c.brandSubtle),
        child: Icon(LucideIcons.plus, size: 22, color: c.brandPrimary),
      ),
    );
  }

  Widget _buildReportInfo() {
    return ZyndioCard(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            controller: _titleController,
            label: 'REPORT TITLE',
            hint: 'e.g. Annual Blood Panel',
            icon: LucideIcons.fileText,
          ),
          const SizedBox(height: 18),
          _buildField(
            controller: _dateController,
            label: 'TEST DATE',
            hint: 'YYYY-MM-DD',
            icon: LucideIcons.calendar,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: ZyndioType.family,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: ZyndioType.callout.copyWith(
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
          keyboardType: label.contains('DATE') ? TextInputType.datetime : TextInputType.text,
          decoration: _zyndioInputDecoration(
            c,
            hint: hint,
            prefixIcon: Icon(icon, size: 18, color: c.textTertiary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(ZyndioColors c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Verification Checkbox ──
        GestureDetector(
          onTap: () => setState(() => _isVerified = !_isVerified),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _isVerified ? c.brandPrimary : c.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isVerified ? c.brandPrimary : c.borderStrong,
                      width: 1.5,
                    ),
                  ),
                  child: _isVerified
                      ? Icon(LucideIcons.check, size: 14, color: c.brandOnPrimary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I verify that the extracted data matches my official laboratory report.',
                    style: ZyndioType.footnote.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _isVerified ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Confirm Button ──
        ZyndioGradientButton(
          label: 'Confirm & Save Report',
          trailingArrow: false,
          loading: _isUploading,
          onTap: (_isUploading || !_isVerified) ? null : _submit,
        ),
      ],
    );
  }
}

/// Token-coloured text-field decoration: surface fill, hairline border,
/// brand-blue focus ring.
InputDecoration _zyndioInputDecoration(
  ZyndioColors c, {
  required String hint,
  Widget? prefixIcon,
  BoxConstraints? prefixIconConstraints,
  EdgeInsets contentPadding =
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  double radius = 14,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontFamily: ZyndioType.family, color: c.textTertiary),
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIconConstraints,
    filled: true,
    fillColor: c.bgSurface,
    isDense: true,
    contentPadding: contentPadding,
    border: border(c.borderSubtle),
    enabledBorder: border(c.borderSubtle),
    focusedBorder: border(c.brandPrimary, 1.5),
  );
}

class _EditableBiomarkerCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRemove;
  final Function(String, dynamic) onUpdate;

  const _EditableBiomarkerCard({
    required Key key,
    required this.data,
    required this.onRemove,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<_EditableBiomarkerCard> createState() => _EditableBiomarkerCardState();
}

class _EditableBiomarkerCardState extends State<_EditableBiomarkerCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _valCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _rangeCtrl;
  late TextEditingController _insightCtrl;
  late TextEditingController _categoryCtrl;
  String _status = 'In-range';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data['name']);
    _valCtrl = TextEditingController(text: widget.data['value']);
    _unitCtrl = TextEditingController(text: widget.data['unit'] ?? '');
    _rangeCtrl = TextEditingController(text: widget.data['range']);
    _insightCtrl = TextEditingController(text: widget.data['insight'] ?? '');
    _categoryCtrl = TextEditingController(text: widget.data['category'] ?? 'General');
    final rawStatus = (widget.data['status'] ?? 'In-range').toString().toLowerCase();
    if (rawStatus == 'optimal') {
      _status = 'Optimal';
    } else if (rawStatus == 'outlier' || rawStatus == 'abnormal' || rawStatus == 'high' || rawStatus == 'low' || rawStatus == 'critical') {
      _status = 'Outlier';
    } else {
      _status = 'In-range';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valCtrl.dispose();
    _unitCtrl.dispose();
    _rangeCtrl.dispose();
    _insightCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    Color statusColor;
    Color statusBg;

    if (_status == 'Optimal') {
      statusColor = c.statusSuccess;
      statusBg = c.statusSuccessSubtle;
    } else if (_status == 'In-Range' || _status == 'Normal' || _status == 'In-range') {
      statusColor = c.statusWarning;
      statusBg = c.statusWarningSubtle;
    } else {
      statusColor = c.statusCritical;
      statusBg = c.statusCriticalSubtle;
    }

    final smallText = TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: c.textSecondary,
    );

    return ZyndioCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Biomarker Name
              Expanded(
                child: TextFormField(
                  controller: _nameCtrl,
                  style: ZyndioType.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Biomarker Name',
                    hintStyle: TextStyle(
                        fontFamily: ZyndioType.family, color: c.textTertiary),
                  ),
                  onChanged: (v) => widget.onUpdate('name', v),
                ),
              ),
              const SizedBox(width: 12),
              // Value
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: _valCtrl,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: ZyndioType.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: ZyndioType.tabular,
                    color: c.textPrimary,
                  ),
                  decoration: _zyndioInputDecoration(c, hint: '0.0', radius: 12),
                  onChanged: (v) => widget.onUpdate('value', v),
                ),
              ),
              const SizedBox(width: 4),
              // Remove
              GestureDetector(
                onTap: widget.onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(LucideIcons.trash2, size: 18, color: c.textTertiary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                // Range
                Expanded(
                  child: TextFormField(
                    controller: _rangeCtrl,
                    style: smallText,
                    decoration: _zyndioInputDecoration(
                      c,
                      hint: 'Reference Range',
                      radius: 12,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 6),
                        child: Icon(LucideIcons.activity, size: 12, color: c.textTertiary),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    onChanged: (v) => widget.onUpdate('range', v),
                  ),
                ),
                const SizedBox(width: 8),
                // Unit
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    controller: _unitCtrl,
                    style: smallText.copyWith(fontWeight: FontWeight.w600),
                    decoration: _zyndioInputDecoration(c, hint: 'Unit', radius: 12),
                    onChanged: (v) => widget.onUpdate('unit', v),
                  ),
                ),
                const SizedBox(width: 8),
                // Status Dropdown
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: DropdownButton<String>(
                      value: ['Optimal', 'In-range', 'Outlier'].contains(_status) ? _status : 'In-range',
                      underline: const SizedBox(),
                      icon: Icon(LucideIcons.chevronDown, size: 12, color: statusColor),
                      isDense: true,
                      dropdownColor: c.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      items: ['Optimal', 'In-range', 'Outlier']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _status = val);
                          widget.onUpdate('status', val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Category & Insight Section
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _categoryCtrl,
                    style: smallText.copyWith(fontWeight: FontWeight.w600),
                    decoration: _zyndioInputDecoration(
                      c,
                      hint: 'Category',
                      radius: 12,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(LucideIcons.tag, size: 12, color: c.textTertiary),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    onChanged: (v) => widget.onUpdate('category', v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _insightCtrl,
                    style: smallText.copyWith(fontWeight: FontWeight.w400, height: 1.4),
                    decoration: _zyndioInputDecoration(c, hint: 'Add notes...', radius: 12),
                    maxLines: 1,
                    onChanged: (v) => widget.onUpdate('insight', v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
