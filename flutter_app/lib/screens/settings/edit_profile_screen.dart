import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/patient_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bioAgeController;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current data
    final profile = ref.read(patientProfileProvider).value;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _ageController = TextEditingController(text: profile?.age?.toString() ?? '');
    _bioAgeController = TextEditingController(text: profile?.bioAge?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioAgeController.dispose();
    super.dispose();
  }


  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Optimistic Update - No loading spinner
    // setState(() => _isLoading = true);

    try {
      final notifier = ref.read(patientProfileProvider.notifier);
      final profile = ref.read(patientProfileProvider).value;
      if (profile == null) throw Exception("No profile loaded");

      final name = _nameController.text.trim();
      final ageText = _ageController.text.trim();
      final age = int.tryParse(ageText);
      if (age == null) throw Exception("Invalid Age");

      // Use the Notifier to update Local State + Sync to Supabase
      print("DEBUG: Calling notifier.updateProfile - Name: $name, Age: $age");
      await notifier.updateProfile(name: name, age: age);

      if (mounted) {
        // Show Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      print("DEBUG: Error updating profile: $e");
      if (mounted) {
        // Even if sync failed, local update succeeded, so we might not want to show error
        // But let's show it as a warning if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated locally (Sync error: $e)')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: context.nc.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Full Name'),
              _buildTextField(
                controller: _nameController,
                hint: 'Enter your name',
                icon: LucideIcons.user,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildLabel('Chronological Age'),
              _buildTextField(
                controller: _ageController,
                hint: 'e.g., 34',
                icon: LucideIcons.calendar,
                isNumber: true,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (int.tryParse(val) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Updating this will reflect in your Dashboard Pace of Aging calculation.',
                style: TextStyle(fontSize: 12, color: BrandColors.slate400),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.nc.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nc.scaffoldBg),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.nc.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: BrandColors.slate400),
        filled: true,
        fillColor: context.nc.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.nc.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.nc.primary),
        ),
      ),
    );
  }
}
