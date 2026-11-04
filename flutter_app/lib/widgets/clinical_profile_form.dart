import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/clinical_profile.dart';
import '../screens/auth/widgets/patient_auth_chrome.dart';

/// APP-04 profile fields: name, date of birth, sex at birth, units and
/// height. Shared by onboarding (step 2) and Settings > Edit profile.
/// Validates the same rules the server enforces (adult DOB, 50-272 cm) and
/// hands back a complete [ClinicalProfile]; saving is the caller's job.
class ClinicalProfileForm extends StatefulWidget {
  const ClinicalProfileForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.saving = false,
    this.today,
  });

  final ClinicalProfile? initial;
  final String submitLabel;
  final Future<void> Function(ClinicalProfile profile) onSubmit;
  final bool saving;

  /// Injectable clock for tests.
  final DateTime? today;

  @override
  State<ClinicalProfileForm> createState() => ClinicalProfileFormState();
}

class ClinicalProfileFormState extends State<ClinicalProfileForm> {
  static const int maxNameLength = 80;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.displayName ?? '');
  final TextEditingController _cm = TextEditingController();
  final TextEditingController _feet = TextEditingController();
  final TextEditingController _inches = TextEditingController();
  DateTime? _dob;
  SexAtBirth? _sex;
  late UnitSystem _units = widget.initial?.unitSystem ?? UnitSystem.imperial;
  String? _dobError;
  String? _sexError;

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void initState() {
    super.initState();
    _dob = widget.initial?.dateOfBirth;
    _sex = widget.initial?.sexAtBirth;
    _fillHeight(widget.initial?.heightCm);
  }

  void _fillHeight(double? cm) {
    if (cm == null) return;
    _cm.text = cm.toStringAsFixed(cm.truncateToDouble() == cm ? 0 : 1);
    final fi = cmToFeetInches(cm);
    _feet.text = '${fi.feet}';
    _inches.text = '${fi.inches}';
  }

  @override
  void dispose() {
    _name.dispose();
    _cm.dispose();
    _feet.dispose();
    _inches.dispose();
    super.dispose();
  }

  /// Height in cm from whichever unit fields are showing, or null if they
  /// don't parse.
  double? _heightCm() {
    if (_units == UnitSystem.metric) {
      return double.tryParse(_cm.text.trim().replaceAll(',', '.'));
    }
    final feet = int.tryParse(_feet.text.trim());
    final inches = _inches.text.trim().isEmpty ? 0.0 : double.tryParse(_inches.text.trim());
    if (feet == null || inches == null || inches < 0 || inches >= 12) return null;
    return feetInchesToCm(feet, inches);
  }

  void _switchUnits(UnitSystem units) {
    if (units == _units) return;
    final cm = _heightCm();
    setState(() {
      _units = units;
      if (cm != null) _fillHeight(cm);
    });
  }

  Future<void> _pickDob() async {
    final last = latestAllowedDob(_today);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(last.year - 22, last.month, 1),
      firstDate: DateTime(1900),
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobError = null;
      });
    }
  }

  String? _validateHeight() {
    final cm = _heightCm();
    if (cm == null) return 'Enter your height.';
    if (cm < kMinHeightCm || cm > kMaxHeightCm) {
      return _units == UnitSystem.metric
          ? 'Enter a height between 50 and 272 cm.'
          : 'Enter a height between 1 ft 8 in and 8 ft 11 in.';
    }
    return null;
  }

  Future<void> _submit() async {
    final fieldsOk = _formKey.currentState!.validate();
    setState(() {
      _dobError = _dob == null
          ? 'Enter your date of birth.'
          : (_dob!.isAfter(latestAllowedDob(_today))
              ? 'You need to be $kMinPatientAge or older to join this program.'
              : null);
      _sexError = _sex == null ? 'Choose one.' : null;
    });
    if (!fieldsOk || _dobError != null || _sexError != null) return;
    await widget.onSubmit(ClinicalProfile(
      displayName: _name.text.trim(),
      dateOfBirth: _dob,
      sexAtBirth: _sex,
      heightCm: _heightCm(),
      unitSystem: _units,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    final labelStyle = TextStyle(color: c.textSecondary, fontSize: 13, height: 18 / 13);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthLabeledField(
            label: 'Full name',
            child: TextFormField(
              key: const Key('profile-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: maxNameLength,
              style: TextStyle(color: c.textPrimary),
              decoration: authFieldDecoration(context).copyWith(counterText: ''),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter your name.';
                if (t.runes.length > maxNameLength) {
                  return 'Use $maxNameLength characters or fewer.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          AuthLabeledField(
            label: 'Date of birth',
            errorText: _dobError,
            child: InkWell(
              key: const Key('profile-dob'),
              onTap: _pickDob,
              child: InputDecorator(
                decoration: authFieldDecoration(context, error: _dobError != null),
                child: Text(
                  _dob == null ? 'Select date' : DateFormat.yMMMMd().format(_dob!),
                  style: TextStyle(color: _dob == null ? c.textTertiary : c.textPrimary, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AuthLabeledField(
            label: 'Sex assigned at birth',
            errorText: _sexError,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<SexAtBirth>(
                  key: const Key('profile-sex'),
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: [
                    for (final s in SexAtBirth.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {if (_sex != null) _sex!},
                  onSelectionChanged: (sel) => setState(() {
                    _sex = sel.isEmpty ? null : sel.first;
                    _sexError = null;
                  }),
                ),
                const SizedBox(height: 6),
                Text('Used to pick the right reference ranges for your lab results.', style: labelStyle),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AuthLabeledField(
            label: 'Units',
            child: SegmentedButton<UnitSystem>(
              key: const Key('profile-units'),
              showSelectedIcon: false,
              segments: [
                for (final u in UnitSystem.values) ButtonSegment(value: u, label: Text(u.label)),
              ],
              selected: {_units},
              onSelectionChanged: (sel) => _switchUnits(sel.first),
            ),
          ),
          const SizedBox(height: 16),
          AuthLabeledField(
            label: 'Height',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_units == UnitSystem.metric)
                  TextFormField(
                    key: const Key('profile-height-cm'),
                    controller: _cm,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: TextStyle(color: c.textPrimary),
                    decoration: authFieldDecoration(context).copyWith(suffixText: 'cm'),
                    validator: (_) => _validateHeight(),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('profile-height-ft'),
                          controller: _feet,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(color: c.textPrimary),
                          decoration: authFieldDecoration(context).copyWith(suffixText: 'ft'),
                          validator: (_) => _validateHeight(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('profile-height-in'),
                          controller: _inches,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(color: c.textPrimary),
                          decoration: authFieldDecoration(context).copyWith(suffixText: 'in'),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (v != null && v.trim().isNotEmpty && (n == null || n > 11)) {
                              return '0-11';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Text('Used to work out your BMI.', style: labelStyle),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: widget.submitLabel,
            loading: widget.saving,
            onPressed: widget.saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
