import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../config/white_label_config.dart';
import '../../models/appointment_model.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/app_card.dart';
import 'widgets/appointment_card.dart';
import 'widgets/reschedule_cancel_dialogs.dart';

class AppointmentsHubScreen extends ConsumerStatefulWidget {
  const AppointmentsHubScreen({super.key});

  @override
  ConsumerState<AppointmentsHubScreen> createState() => _AppointmentsHubScreenState();
}

class _AppointmentsHubScreenState extends ConsumerState<AppointmentsHubScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _specialties = [
    'All',
    'Longevity & Anti-Aging',
    'Preventive Cardiology',
    'Metabolic & Functional Medicine',
    'Neurology & Cognitive Longevity',
    'Genomics & Peptide Therapy',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
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
    final wlConfig = ref.watch(whiteLabelConfigProvider);
    final filteredDoctorsAsync = ref.watch(filteredDoctorsProvider);
    final userAppointmentsAsync = ref.watch(userAppointmentsProvider);
    final selectedSpecialty = ref.watch(selectedSpecialtyFilterProvider);
    final hospitalPartnersAsync = ref.watch(hospitalPartnersProvider);
    final selectedHospital = ref.watch(selectedHospitalFilterProvider);

    final filteredDoctors = filteredDoctorsAsync.value ?? [];
    final userAppointments = userAppointmentsAsync.value ?? [];
    final hospitalPartners = hospitalPartnersAsync.value ?? [];

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
                      top: MediaQuery.of(context).size.height * 0.08,
                      right: -80,
                      child: _buildAuroraBlob(BrandColors.indigo500, 0.25 + (0.08 * pulse)),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.45,
                      left: -100,
                      child: _buildAuroraBlob(BrandColors.purple500, 0.20 + (0.06 * pulse)),
                    ),
                    Positioned(
                      bottom: -60,
                      right: MediaQuery.of(context).size.width * 0.1,
                      child: _buildAuroraBlob(BrandColors.blue500, 0.18 + (0.05 * pulse)),
                    ),
                  ],
                );
              },
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
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
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wlConfig.hospitalBrandName,
                              style: TextStyle(
                                color: BrandColors.indigo400,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              wlConfig.tagline,
                              style: TextStyle(
                                color: nc.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Custom Animated Segmented Toggle Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: nc.cardSurface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: nc.cardBorder),
                      ),
                      child: Row(
                        children: [
                          _buildSegmentItem(
                            index: 0,
                            label: 'Book Consultation',
                            isSelected: _tabController.index == 0,
                            nc: nc,
                          ),
                          _buildSegmentItem(
                            index: 1,
                            label: 'My Appointments',
                            badgeCount: userAppointments.where((a) => a.status == AppointmentStatus.confirmed).length,
                            isSelected: _tabController.index == 1,
                            nc: nc,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Content Area
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Book Consultation
                        _buildBookTab(filteredDoctors, selectedSpecialty, hospitalPartners, selectedHospital),

                        // Tab 2: My Appointments
                        _buildAppointmentsListTab(userAppointments),
                      ],
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

  /// Custom Segmented Control Item
  Widget _buildSegmentItem({
    required int index,
    required String label,
    required bool isSelected,
    required BrandThemeColors nc,
    int badgeCount = 0,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          if (mounted) setState(() {});
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? BrandColors.indigo500 : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: BrandColors.indigo500.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : nc.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : BrandColors.emerald500,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Tab 1 Widget: Book Consultation & Doctor Directory
  Widget _buildBookTab(
    List<DoctorProfile> doctors,
    String selectedSpecialty,
    List<HospitalClinic> hospitals,
    String selectedHospital,
  ) {
    final nc = context.nc;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: nc.inputFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: nc.inputBorder),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(doctorSearchQueryProvider.notifier).setQuery(val);
              },
              style: TextStyle(color: nc.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search doctor, specialty, or hospital...',
                hintStyle: TextStyle(color: nc.textTertiary, fontSize: 14),
                prefixIcon: const Icon(LucideIcons.search, color: BrandColors.indigo400, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(LucideIcons.x, color: nc.iconSubtle, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(doctorSearchQueryProvider.notifier).setQuery('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Partner Hospital Network Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Partner Hospital Networks',
                style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (selectedHospital != 'All')
                GestureDetector(
                  onTap: () => ref.read(selectedHospitalFilterProvider.notifier).setFilter('All'),
                  child: const Text(
                    'Clear Filter',
                    style: TextStyle(color: BrandColors.indigo400, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: hospitals.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAllSelected = selectedHospital == 'All';
                  return _buildHospitalChip(
                    name: 'All Hospitals',
                    subtitle: '${hospitals.length} Affiliated Networks',
                    isSelected: isAllSelected,
                    onTap: () => ref.read(selectedHospitalFilterProvider.notifier).setFilter('All'),
                  );
                }
                final hospital = hospitals[index - 1];
                final isSelected = selectedHospital == hospital.name;
                return _buildHospitalChip(
                  name: hospital.name,
                  subtitle: hospital.city,
                  isSelected: isSelected,
                  onTap: () => ref.read(selectedHospitalFilterProvider.notifier).setFilter(hospital.name),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Specialty Filter Chips
          Text(
            'Filter by Clinical Specialty',
            style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _specialties.map((spec) {
                final isSelected = selectedSpecialty == spec;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(spec),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(selectedSpecialtyFilterProvider.notifier).setFilter(spec);
                      }
                    },
                    selectedColor: BrandColors.indigo500,
                    backgroundColor: nc.cardSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : nc.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? BrandColors.indigo400 : nc.cardBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Doctors Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Specialists (${doctors.length})',
                style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(LucideIcons.slidersHorizontal, size: 16, color: nc.iconSubtle),
            ],
          ),
          const SizedBox(height: 14),

          // Doctor List Cards
          if (doctors.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(LucideIcons.userX, size: 48, color: nc.iconSubtle),
                  const SizedBox(height: 12),
                  Text(
                    'No specialists found',
                    style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try adjusting your specialty or hospital search filters.',
                    style: TextStyle(color: nc.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return _buildDoctorCard(doctor);
              },
            ),
        ],
      ),
    );
  }

  /// Hospital Chip Widget
  Widget _buildHospitalChip({
    required String name,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final nc = context.nc;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(18),
        backgroundColor: isSelected ? BrandColors.indigo500 : nc.cardSurface,
        borderColor: isSelected ? BrandColors.indigo400 : nc.cardBorder,
        child: SizedBox(
          width: 156,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.building2,
                    size: 16,
                    color: isSelected ? Colors.white : BrandColors.indigo400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : nc.textPrimary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? Colors.white.withValues(alpha: 0.8) : nc.textTertiary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Doctor Card Widget using AppCard
  Widget _buildDoctorCard(DoctorProfile doctor) {
    final nc = context.nc;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      backgroundColor: nc.cardSurface,
      borderColor: nc.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Image & Rating Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: BrandColors.indigo500.withValues(alpha: 0.2),
                    backgroundImage: doctor.avatarUrl.isNotEmpty ? NetworkImage(doctor.avatarUrl) : null,
                    child: doctor.avatarUrl.isEmpty
                        ? Text(
                            doctor.name.split(' ').last.substring(0, 1),
                            style: TextStyle(color: nc.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -6,
                    left: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BrandColors.amber500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.star, size: 10, color: Colors.black),
                          const SizedBox(width: 2),
                          Text(
                            '${doctor.rating}',
                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Doctor Specs & Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${doctor.name}, ${doctor.title}',
                      style: TextStyle(color: nc.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doctor.specialty,
                      style: const TextStyle(color: BrandColors.indigo400, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.building2, size: 12, color: nc.iconSubtle),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doctor.hospitalName,
                            style: TextStyle(color: nc.textTertiary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Doctor Bio Excerpt
          Text(
            doctor.bio,
            style: TextStyle(color: nc.textSecondary, fontSize: 12, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Footer Row: Availability & Book Action
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: nc.isDark ? Colors.black.withValues(alpha: 0.3) : BrandColors.slate100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: nc.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.clock, size: 12, color: BrandColors.emerald500),
                        const SizedBox(width: 4),
                        Text(
                          'Next Slot',
                          style: TextStyle(color: nc.textTertiary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor.nextAvailableSlot,
                      style: TextStyle(color: nc.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    context.push('/appointments/doctor/${doctor.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.indigo500,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    children: [
                      Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(width: 6),
                      Icon(LucideIcons.chevronRight, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 2 Widget: My Appointments
  Widget _buildAppointmentsListTab(List<AppointmentBooking> appointments) {
    final nc = context.nc;

    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.calendarX, size: 56, color: nc.iconSubtle),
            const SizedBox(height: 16),
            Text(
              'No upcoming appointments',
              style: TextStyle(color: nc.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Book a consultation with top longevity doctors & specialists.',
              style: TextStyle(color: nc.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
              },
              icon: const Icon(LucideIcons.plusCircle, size: 16),
              label: const Text('Book Your First Appointment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.indigo500,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final booking = appointments[index];
        return AppointmentCard(
          booking: booking,
          onCancel: () {
            _showCancelDialog(booking);
          },
          onReschedule: () {
            _showRescheduleDialog(booking);
          },
        );
      },
    );
  }

  /// Cancel Dialog Confirmation
  void _showCancelDialog(AppointmentBooking booking) {
    CancelAppointmentDialog.show(
      context,
      booking,
      (reason) async {
        await ref.read(userAppointmentsProvider.notifier).cancelAppointment(booking.id, reason: reason);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled.'),
            backgroundColor: BrandColors.red500,
          ),
        );
      },
    );
  }

  /// Reschedule Dialog
  void _showRescheduleDialog(AppointmentBooking booking) {
    RescheduleAppointmentBottomSheet.show(
      context,
      booking,
      (newDate, newTimeSlot) async {
        await ref.read(userAppointmentsProvider.notifier).rescheduleAppointment(
              booking.id,
              newDate,
              newTimeSlot,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rescheduled to ${DateFormat('EEE, MMM d').format(newDate)} at $newTimeSlot'),
            backgroundColor: BrandColors.emerald500,
          ),
        );
      },
    );
  }
}
