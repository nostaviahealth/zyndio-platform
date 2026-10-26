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
        'range': '',
        'status': 'Normal',
        'category': 'General',
        'insight': '',
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
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: Stack(
        children: [
          // ── Clean Ambient Background ──
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BrandColors.emerald500.withValues(alpha: 0.1),
                    BrandColors.emerald500.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Custom Header ──
                _buildHeader(),

                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    children: [
                      // Report Info Section
                      _buildReportInfo(),
                      
                      const SizedBox(height: 32),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'BIOMARKERS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.3),
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            '${_markers.length} found',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ...List.generate(_markers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
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

                      const SizedBox(height: 200), // Spacing for bottom button
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Action ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomAction(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              child: const Icon(LucideIcons.arrowLeft, size: 20, color: Colors.white),
            ),
          ),
          const Expanded(
            child: Text(
              'Verify Results',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: _addMarker,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BrandColors.emerald500.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.emerald500.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(LucideIcons.plus, size: 20, color: BrandColors.emerald400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            controller: _titleController,
            label: 'REPORT TITLE',
            hint: 'e.g. Annual Blood Panel',
            icon: LucideIcons.fileText,
          ),
          const SizedBox(height: 24),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.3),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          keyboardType: label.contains('DATE') ? TextInputType.datetime : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            prefixIcon: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.3)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.nc.scaffoldBg.withValues(alpha: 0),
            context.nc.scaffoldBg.withValues(alpha: 0.95),
            context.nc.scaffoldBg,
          ],
          stops: const [0, 0.4, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Verification Checkbox ──
          GestureDetector(
            onTap: () => setState(() => _isVerified = !_isVerified),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _isVerified ? BrandColors.emerald500 : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isVerified ? BrandColors.emerald500 : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: _isVerified 
                      ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                      : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'I verify that the extracted data matches my official laboratory report.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isVerified ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ── Confirm Button ──
          GestureDetector(
            onTap: (_isUploading || !_isVerified) ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                color: _isVerified 
                  ? BrandColors.emerald500 
                  : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                boxShadow: _isVerified ? [
                  BoxShadow(
                    color: BrandColors.emerald500.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ] : [],
              ),
              child: Center(
                child: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Confirm & Save Report',
                        style: TextStyle(
                          color: _isVerified ? Colors.white : Colors.white.withValues(alpha: 0.2),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    Color statusColor;
    Color statusBg;

    if (_status == 'Optimal') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.1);
    } else if (_status == 'In-Range' || _status == 'Normal' || _status == 'In-range') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
    } else {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white, letterSpacing: -0.3),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Biomarker Name',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  onChanged: (v) => widget.onUpdate('name', v),
                ),
              ),
              const SizedBox(width: 12),
              // Value
              Container(
                width: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: TextFormField(
                  controller: _valCtrl,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0.0',
                    hintStyle: TextStyle(color: Colors.white10),
                  ),
                  onChanged: (v) => widget.onUpdate('value', v),
                ),
              ),
              const SizedBox(width: 12),
              // Remove
              GestureDetector(
                onTap: widget.onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(LucideIcons.trash2, size: 18, color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          Row(
            children: [
              // Range
              Expanded(
                child: TextFormField(
                  controller: _rangeCtrl,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Reference Range',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15)),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(LucideIcons.activity, size: 12, color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                  onChanged: (v) => widget.onUpdate('range', v),
                ),
              ),
              const SizedBox(width: 8),
              // Unit
              Container(
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: TextFormField(
                  controller: _unitCtrl,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Unit',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  onChanged: (v) => widget.onUpdate('unit', v),
                ),
              ),
              const SizedBox(width: 8),
              // Status Dropdown
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: DropdownButton<String>(
                    value: ['Optimal', 'In-range', 'Outlier'].contains(_status) ? _status : 'In-range',
                    underline: const SizedBox(),
                    icon: Icon(LucideIcons.chevronDown, size: 12, color: statusColor.withValues(alpha: 0.7)),
                    isDense: true,
                    dropdownColor: context.nc.cardSurfaceElevated,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
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

          const SizedBox(height: 14),

          // Category & Insight Section
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.tag, size: 12, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _categoryCtrl,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Category',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => widget.onUpdate('category', v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _insightCtrl,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3), height: 1.4),
                    decoration: InputDecoration(
                      hintText: 'Add notes...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 1,
                    onChanged: (v) => widget.onUpdate('insight', v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
