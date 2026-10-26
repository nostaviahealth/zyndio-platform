import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/appointment_model.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_card.dart';
import 'appointment_pass_dialog.dart';

class AppointmentCard extends StatefulWidget {
  final AppointmentBooking booking;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  const AppointmentCard({
    super.key,
    required this.booking,
    required this.onCancel,
    required this.onReschedule,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;
  bool _isAnimationInitialized = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    if (_isAnimationInitialized) return;
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.fastOutSlowIn,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(_expandAnimation);
    _isAnimationInitialized = true;
  }

  @override
  void reassemble() {
    super.reassemble();
    if (!_isAnimationInitialized) {
      _initAnimation();
    }
  }

  @override
  void dispose() {
    if (_isAnimationInitialized) {
      _expandController.dispose();
    }
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  Color _getStatusColor() {
    switch (widget.booking.status) {
      case AppointmentStatus.confirmed:
        return BrandColors.emerald500;
      case AppointmentStatus.completed:
        return BrandColors.blue500;
      case AppointmentStatus.cancelled:
        return BrandColors.red500;
      case AppointmentStatus.rescheduled:
        return BrandColors.amber500;
    }
  }

  @override
  Widget build(BuildContext context) {
    _initAnimation();
    final nc = context.nc;
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final formattedDate = dateFormat.format(widget.booking.appointmentDate);
    final shortDate = DateFormat('EEE, MMM d').format(widget.booking.appointmentDate);
    final statusColor = _getStatusColor();
    final isUpcoming = widget.booking.status == AppointmentStatus.confirmed ||
        widget.booking.status == AppointmentStatus.rescheduled;

    return GestureDetector(
      onTap: _toggleExpand,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(22),
        backgroundColor: nc.cardSurface,
        borderColor: nc.cardBorder,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. COMPACT ALWAYS-VISIBLE HEADER ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrandColors.indigo500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BrandColors.indigo400.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.stethoscope, size: 13, color: BrandColors.indigo400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.booking.specialty,
                          style: const TextStyle(
                            color: BrandColors.indigo400,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.booking.status.label.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RotationTransition(
                turns: _rotationAnimation,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 18,
                  color: _isExpanded ? BrandColors.indigo400 : nc.iconSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Doctor Summary Row
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: BrandColors.indigo500.withValues(alpha: 0.2),
                backgroundImage: widget.booking.doctorAvatarUrl.isNotEmpty
                    ? NetworkImage(widget.booking.doctorAvatarUrl)
                    : null,
                child: widget.booking.doctorAvatarUrl.isEmpty
                    ? Text(
                        widget.booking.doctorName.split(' ').last.substring(0, 1),
                        style: TextStyle(color: nc.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.booking.doctorName,
                            style: TextStyle(
                              color: nc.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.booking.doctorTitle,
                          style: TextStyle(
                            color: nc.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.booking.hospitalName,
                      style: TextStyle(
                        color: nc.textTertiary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Compact Quick Info Badge (Date & Time Pill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: nc.isDark ? Colors.black.withValues(alpha: 0.3) : BrandColors.slate100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: nc.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 14, color: BrandColors.indigo400),
                    const SizedBox(width: 6),
                    Text(
                      '$shortDate • ${widget.booking.timeSlot}',
                      style: TextStyle(
                        color: nc.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      widget.booking.type == ConsultationType.telehealth
                          ? LucideIcons.video
                          : (widget.booking.type == ConsultationType.inPerson ? LucideIcons.building : LucideIcons.home),
                      size: 14,
                      color: BrandColors.emerald500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.booking.type.displayName,
                      style: const TextStyle(
                        color: BrandColors.emerald500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 2. BUTTERY-SMOOTH SIZE & FADE EXPANSION ──
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),

                  // Location / Telehealth Full Details Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: nc.isDark ? Colors.black.withValues(alpha: 0.2) : BrandColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: nc.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              widget.booking.type == ConsultationType.inPerson
                                  ? LucideIcons.mapPin
                                  : LucideIcons.info,
                              size: 14,
                              color: nc.iconSubtle,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Full Date: $formattedDate',
                              style: TextStyle(color: nc.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Location: ${widget.booking.locationAddress}',
                          style: TextStyle(
                            color: nc.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (widget.booking.reasonNotes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Note: "${widget.booking.reasonNotes}"',
                        style: TextStyle(
                          color: nc.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                // Digital Check-in QR Pass Row
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => AppointmentPassDialog.show(context, widget.booking),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: BrandColors.indigo500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BrandColors.indigo400.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.qrCode, size: 14, color: BrandColors.indigo400),
                            const SizedBox(width: 6),
                            Text(
                              'Hospital Pass: ${widget.booking.qrPassCode}',
                              style: const TextStyle(
                                color: BrandColors.indigo400,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'View QR',
                              style: TextStyle(color: nc.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 2),
                            Icon(LucideIcons.chevronRight, size: 14, color: nc.iconSubtle),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons for Upcoming Appointments
                if (isUpcoming) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (widget.booking.type == ConsultationType.inPerson)
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () async {
                              final query = Uri.encodeComponent(
                                  '${widget.booking.hospitalName}, ${widget.booking.locationAddress}');
                              final mapsUrl = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$query');
                              if (await canLaunchUrl(mapsUrl)) {
                                await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Hospital Address: ${widget.booking.locationAddress}'),
                                    backgroundColor: BrandColors.indigo500,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [BrandColors.indigo500, BrandColors.indigo600],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: BrandColors.indigo500.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.navigation, size: 14, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'Get Directions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (widget.booking.type == ConsultationType.telehealth &&
                          widget.booking.videoCallUrl != null)
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(widget.booking.videoCallUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [BrandColors.indigo500, BrandColors.indigo600],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: BrandColors.indigo500.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.video, size: 15, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'Join Video Call',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onReschedule,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: nc.cardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            'Reschedule',
                            style: TextStyle(color: nc.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: widget.onCancel,
                        icon: const Icon(LucideIcons.xCircle, size: 18, color: BrandColors.red400),
                        tooltip: 'Cancel Appointment',
                      ),
                    ],
                  ),
                ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
