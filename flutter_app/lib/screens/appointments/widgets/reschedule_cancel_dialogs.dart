import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/appointment_model.dart';
import '../../../config/theme.dart';

class CancelAppointmentDialog extends StatefulWidget {
  final AppointmentBooking booking;
  final Function(String reason) onConfirmCancel;

  const CancelAppointmentDialog({
    super.key,
    required this.booking,
    required this.onConfirmCancel,
  });

  static void show(BuildContext context, AppointmentBooking booking, Function(String reason) onConfirmCancel) {
    showDialog(
      context: context,
      builder: (ctx) => CancelAppointmentDialog(booking: booking, onConfirmCancel: onConfirmCancel),
    );
  }

  @override
  State<CancelAppointmentDialog> createState() => _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState extends State<CancelAppointmentDialog> {
  String _selectedReason = 'Schedule Conflict';
  final TextEditingController _customReasonController = TextEditingController();

  final List<String> _cancellationReasons = [
    'Schedule Conflict',
    'Feeling Better / Symptoms Resolved',
    'Switching Specialist',
    'Found Earlier Appointment Elsewhere',
    'Other Reason',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;

    return AlertDialog(
      backgroundColor: nc.cardSurfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: nc.cardBorder),
      ),
      title: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: BrandColors.amber500, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cancel Appointment',
              style: TextStyle(color: nc.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel your visit with ${widget.booking.doctorName}?',
              style: TextStyle(color: nc.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Reason for Cancellation:',
              style: TextStyle(color: nc.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._cancellationReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                        size: 18,
                        color: isSelected ? BrandColors.indigo400 : nc.iconSubtle,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            color: isSelected ? nc.textPrimary : nc.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_selectedReason == 'Other Reason') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customReasonController,
                style: TextStyle(color: nc.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Please specify reason...',
                  hintStyle: TextStyle(color: nc.textTertiary, fontSize: 12),
                  filled: true,
                  fillColor: nc.inputFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: nc.inputBorder),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Keep Appointment', style: TextStyle(color: nc.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final finalReason = _selectedReason == 'Other Reason'
                ? (_customReasonController.text.isEmpty ? 'Other Reason' : _customReasonController.text)
                : _selectedReason;
            widget.onConfirmCancel(finalReason);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandColors.red500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Confirm Cancellation', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class RescheduleAppointmentBottomSheet extends StatefulWidget {
  final AppointmentBooking booking;
  final Function(DateTime newDate, String newTimeSlot) onConfirmReschedule;

  const RescheduleAppointmentBottomSheet({
    super.key,
    required this.booking,
    required this.onConfirmReschedule,
  });

  static void show(BuildContext context, AppointmentBooking booking, Function(DateTime newDate, String newTimeSlot) onConfirmReschedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RescheduleAppointmentBottomSheet(
        booking: booking,
        onConfirmReschedule: onConfirmReschedule,
      ),
    );
  }

  @override
  State<RescheduleAppointmentBottomSheet> createState() => _RescheduleAppointmentBottomSheetState();
}

class _RescheduleAppointmentBottomSheetState extends State<RescheduleAppointmentBottomSheet> {
  late DateTime _selectedDate;
  late String _selectedTimeSlot;

  final List<String> _availableSlots = [
    '09:00 AM',
    '10:30 AM',
    '01:15 PM',
    '03:00 PM',
    '04:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.booking.appointmentDate.add(const Duration(days: 1));
    _selectedTimeSlot = _availableSlots.first;
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;
    final dateFormat = DateFormat('EEE, MMM d, yyyy');

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: nc.cardSurfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: nc.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: nc.iconSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(LucideIcons.calendar, color: BrandColors.indigo400, size: 20),
              const SizedBox(width: 10),
              Text(
                'Reschedule Visit',
                style: TextStyle(color: nc.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select a new date and time slot for ${widget.booking.doctorName}',
            style: TextStyle(color: nc.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Date Selector Button
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: nc.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: nc.inputBorder),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 18, color: BrandColors.indigo400),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Date', style: TextStyle(color: nc.textTertiary, fontSize: 11)),
                      Text(
                        dateFormat.format(_selectedDate),
                        style: TextStyle(color: nc.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(LucideIcons.chevronRight, size: 18, color: nc.iconSubtle),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Available Time Slots:', style: TextStyle(color: nc.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSlots.map((slot) {
              final isSelected = _selectedTimeSlot == slot;
              return ChoiceChip(
                label: Text(slot),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedTimeSlot = slot);
                },
                selectedColor: BrandColors.indigo500,
                backgroundColor: nc.cardSurface,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : nc.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? BrandColors.indigo400 : nc.cardBorder,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirmReschedule(_selectedDate, _selectedTimeSlot);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.indigo500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Confirm Reschedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
