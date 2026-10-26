import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/appointment_model.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/app_card.dart';
import 'widgets/appointment_pass_dialog.dart';

class DoctorDetailScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> with TickerProviderStateMixin {
  ConsultationType _selectedType = ConsultationType.inPerson;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '02:30 PM';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController(text: 'Alexander Wright');
  final TextEditingController _patientPhoneController = TextEditingController(text: '+1 (555) 234-5678');
  final TextEditingController _insuranceIdController = TextEditingController();
  bool _isBookingInProcess = false;
  late AnimationController _pulseController;

  final List<String> _aiSuggestions = [
    'Biomarker & Lab Review',
    'NAD+ Cellular Protocol',
    'Cardiovascular Health',
    'Hormone & Metabolic Check',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _reasonController.dispose();
    _patientNameController.dispose();
    _patientPhoneController.dispose();
    _insuranceIdController.dispose();
    super.dispose();
  }

  Widget _buildAuroraBlob(Color color, double opacity) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;
    final doctorsAsync = ref.watch(doctorsListProvider);
    final doctors = doctorsAsync.value ?? [];
    if (doctors.isEmpty) {
      return Scaffold(
        backgroundColor: nc.scaffoldBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final doctor = doctors.firstWhere(
      (d) => d.id == widget.doctorId,
      orElse: () => doctors.first,
    );

    final availableDates = List.generate(7, (index) => DateTime.now().add(Duration(days: index + 1)));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: nc.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: nc.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: nc.scaffoldBg,
        body: Stack(
          children: [
            // Zyndio Ambient Aurora Background Blobs
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = _pulseController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.05,
                      left: -80,
                      child: _buildAuroraBlob(BrandColors.indigo500, 0.22 + (0.06 * pulse)),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.50,
                      right: -100,
                      child: _buildAuroraBlob(BrandColors.purple500, 0.18 + (0.05 * pulse)),
                    ),
                  ],
                );
              },
            ),

            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: nc.cardSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: nc.cardBorder),
                            ),
                            child: Icon(LucideIcons.arrowLeft, color: nc.textPrimary, size: 20),
                          ),
                        ),
                        Text(
                          'Specialist Profile',
                          style: TextStyle(color: nc.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(LucideIcons.share2, color: nc.iconSubtle, size: 20),
                        ),
                      ],
                    ),
                  ),

                  // Main Booking Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Doctor Hero Profile Card
                          _buildDoctorHeroCard(doctor),
                          const SizedBox(height: 24),

                          // Section 1: Consultation Type
                          Text(
                            'Select Consultation Type',
                            style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: doctor.supportedTypes.map((type) {
                              final isSelected = _selectedType == type;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedType = type),
                                  child: AppCard(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    borderRadius: BorderRadius.circular(16),
                                    backgroundColor: isSelected
                                        ? BrandColors.indigo500.withValues(alpha: 0.2)
                                        : nc.cardSurface,
                                    borderColor: isSelected ? BrandColors.indigo400 : nc.cardBorder,
                                    child: Column(
                                      children: [
                                        Icon(
                                          type == ConsultationType.telehealth
                                              ? LucideIcons.video
                                              : (type == ConsultationType.inPerson ? LucideIcons.building : LucideIcons.home),
                                          color: isSelected ? BrandColors.indigo400 : nc.iconSubtle,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          type.displayName,
                                          style: TextStyle(
                                            color: isSelected ? nc.textPrimary : nc.textSecondary,
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Section 2: Date Picker
                          Text(
                            'Select Appointment Date',
                            style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 72,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: availableDates.length,
                              itemBuilder: (context, index) {
                                final date = availableDates[index];
                                final isSelected = _selectedDate.day == date.day && _selectedDate.month == date.month;
                                final dayName = DateFormat('EEE').format(date);
                                final dayNum = DateFormat('d').format(date);
                                final monthName = DateFormat('MMM').format(date);

                                return GestureDetector(
                                  onTap: () => setState(() => _selectedDate = date),
                                  child: AppCard(
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: EdgeInsets.zero,
                                    borderRadius: BorderRadius.circular(16),
                                    backgroundColor: isSelected ? BrandColors.indigo500 : nc.cardSurface,
                                    borderColor: isSelected ? BrandColors.indigo400 : nc.cardBorder,
                                    child: SizedBox(
                                      width: 64,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            dayName.toUpperCase(),
                                            style: TextStyle(
                                              color: isSelected ? Colors.white.withValues(alpha: 0.8) : nc.textTertiary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dayNum,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : nc.textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            monthName,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white.withValues(alpha: 0.8) : nc.textTertiary,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section 3: Time Slot Selector
                          Text(
                            'Available Time Slots',
                            style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: doctor.availableTimeSlots.map((slot) {
                              final isSelected = _selectedSlot == slot;
                              return ChoiceChip(
                                label: Text(slot),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedSlot = slot);
                                },
                                selectedColor: BrandColors.indigo500,
                                backgroundColor: nc.cardSurface,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : nc.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isSelected ? BrandColors.indigo400 : nc.cardBorder,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Section 4: Reason / Notes
                          Text(
                            'Reason for Visit / Clinical Focus',
                            style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: _aiSuggestions.map((sugg) {
                                final isSelected = _reasonController.text == sugg;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(sugg),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _reasonController.text = selected ? sugg : '';
                                      });
                                    },
                                    selectedColor: BrandColors.indigo500,
                                    backgroundColor: nc.cardSurface,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : BrandColors.indigo400,
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isSelected ? BrandColors.indigo400 : BrandColors.indigo400.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: nc.inputFill,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: nc.inputBorder),
                            ),
                            child: TextField(
                              controller: _reasonController,
                              style: TextStyle(color: nc.textPrimary, fontSize: 14),
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Describe any symptoms or specific goals for this consultation...',
                                hintStyle: TextStyle(color: nc.textTertiary, fontSize: 13),
                                contentPadding: const EdgeInsets.all(14),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section 5: Patient EMR Registration Details
                          Text(
                            'Patient Information (EMR Registration)',
                            style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: nc.inputFill,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: nc.inputBorder),
                                  ),
                                  child: TextField(
                                    controller: _patientNameController,
                                    style: TextStyle(color: nc.textPrimary, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      labelStyle: TextStyle(color: nc.textTertiary, fontSize: 12),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: nc.inputFill,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: nc.inputBorder),
                                  ),
                                  child: TextField(
                                    controller: _patientPhoneController,
                                    style: TextStyle(color: nc.textPrimary, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      labelStyle: TextStyle(color: nc.textTertiary, fontSize: 12),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: nc.inputFill,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: nc.inputBorder),
                            ),
                            child: TextField(
                              controller: _insuranceIdController,
                              style: TextStyle(color: nc.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Insurance ID / Medical Record # (Optional)',
                                labelStyle: TextStyle(color: nc.textTertiary, fontSize: 12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),

                  // Ultra-Premium Floating Glass Bottom Action Bar
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: nc.isDark ? const Color(0xEB0F172A) : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: BrandColors.indigo400.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: BrandColors.indigo500.withValues(alpha: 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Fee Breakdown & Shield Badge
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.shieldCheck, size: 12, color: BrandColors.emerald500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Verified Hospital Fee',
                                      style: TextStyle(
                                        color: nc.textTertiary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '\$${doctor.consultationFee.toInt()}',
                                      style: TextStyle(
                                        color: nc.textPrimary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '/ visit',
                                      style: TextStyle(
                                        color: nc.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),

                            // Glow Action Button
                            Expanded(
                              child: GestureDetector(
                                onTap: _isBookingInProcess ? null : () => _confirmBooking(doctor),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [BrandColors.indigo500, BrandColors.indigo600],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: BrandColors.indigo500.withValues(alpha: 0.45),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _isBookingInProcess
                                      ? const Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Confirm & Book',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero Doctor Profile Card
  Widget _buildDoctorHeroCard(DoctorProfile doctor) {
    final nc = context.nc;

    return AppCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      backgroundColor: nc.cardSurface,
      borderColor: nc.cardBorder,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: BrandColors.indigo500.withValues(alpha: 0.3),
                backgroundImage: doctor.avatarUrl.isNotEmpty ? NetworkImage(doctor.avatarUrl) : null,
                child: doctor.avatarUrl.isEmpty
                    ? Text(doctor.name.split(' ').last.substring(0, 1), style: TextStyle(color: nc.textPrimary, fontSize: 24))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${doctor.name}, ${doctor.title}',
                      style: TextStyle(color: nc.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.specialty,
                      style: const TextStyle(color: BrandColors.indigo400, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.hospitalName,
                      style: TextStyle(color: nc.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Doctor Stats Row (Experience, Rating, Reviews)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: nc.isDark ? Colors.black.withValues(alpha: 0.3) : BrandColors.slate100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: nc.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Experience', '${doctor.experienceYears}+ Yrs'),
                Container(height: 24, width: 1, color: nc.divider),
                _buildStatItem('Rating', '★ ${doctor.rating}'),
                Container(height: 24, width: 1, color: nc.divider),
                _buildStatItem('Reviews', '${doctor.reviewCount}+'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final nc = context.nc;
    return Column(
      children: [
        Text(value, style: TextStyle(color: nc.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: nc.textTertiary, fontSize: 11)),
      ],
    );
  }

  /// Confirm Booking Flow
  Future<void> _confirmBooking(DoctorProfile doctor) async {
    final nc = context.nc;
    setState(() => _isBookingInProcess = true);

    try {
      final booking = await ref.read(userAppointmentsProvider.notifier).bookAppointment(
            doctor: doctor,
            type: _selectedType,
            date: _selectedDate,
            timeSlot: _selectedSlot,
            reasonNotes: _reasonController.text.trim(),
            patientName: _patientNameController.text.trim(),
            patientPhone: _patientPhoneController.text.trim(),
            insuranceId: _insuranceIdController.text.trim(),
          );

      if (!mounted) return;
      setState(() => _isBookingInProcess = false);

      // Show Confirmation Sheet
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: nc.isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: BrandColors.emerald500.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BrandColors.emerald500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.checkCircle2, color: BrandColors.emerald500, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Appointment Confirmed!',
                style: TextStyle(color: nc.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your consultation with ${doctor.name} is booked for ${DateFormat('EEE, MMM d').format(_selectedDate)} at $_selectedSlot.',
                style: TextStyle(color: nc.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        AppointmentPassDialog.show(context, booking);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: BrandColors.indigo400.withValues(alpha: 0.5)),
                      ),
                      child: const Text('Check-In Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop(); // Pop back to appointments hub
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.indigo500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBookingInProcess = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking error: $e'), backgroundColor: BrandColors.red500),
      );
    }
  }
}
