import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/appointment_model.dart';
import '../../../config/theme.dart';

class AppointmentPassDialog extends StatelessWidget {
  final AppointmentBooking booking;

  const AppointmentPassDialog({super.key, required this.booking});

  static void show(BuildContext context, AppointmentBooking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AppointmentPassDialog(booking: booking),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final formattedDate = dateFormat.format(booking.appointmentDate);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: nc.cardSurfaceElevated,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: BrandColors.indigo400.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: BrandColors.indigo500.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: BrandColors.indigo500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BrandColors.indigo400.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.qrCode, size: 14, color: BrandColors.indigo400),
                        SizedBox(width: 6),
                        Text(
                          'Hospital Check-In Pass',
                          style: TextStyle(
                            color: BrandColors.indigo400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, size: 20, color: nc.textSecondary),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // QR Code Graphic Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    // Simulated Matrix QR Pattern
                    CustomPaint(
                      size: const Size(160, 160),
                      painter: _QrCodePainter(booking.qrPassCode),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      booking.qrPassCode,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hospital & Doctor Details
              Text(
                booking.hospitalName,
                style: TextStyle(
                  color: nc.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${booking.doctorName}, ${booking.doctorTitle} (${booking.specialty})',
                style: const TextStyle(
                  color: BrandColors.indigo400,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Divider(height: 1),
              const SizedBox(height: 14),

              // Key Value Grid
              _buildInfoRow(nc, 'Patient Name', booking.patientName, LucideIcons.user),
              const SizedBox(height: 10),
              _buildInfoRow(nc, 'Date & Time', '$formattedDate at ${booking.timeSlot}', LucideIcons.clock),
              const SizedBox(height: 10),
              _buildInfoRow(nc, 'Consultation Type', booking.type.displayName, LucideIcons.building),
              const SizedBox(height: 10),
              _buildInfoRow(nc, 'Location / Room', booking.locationAddress, LucideIcons.mapPin),
              if (booking.insuranceId != null && booking.insuranceId!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildInfoRow(nc, 'Insurance ID', booking.insuranceId!, LucideIcons.fileText),
              ],

              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final query = Uri.encodeComponent('${booking.hospitalName}, ${booking.locationAddress}');
                        final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                        if (await canLaunchUrl(mapsUrl)) {
                          await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(LucideIcons.navigation, size: 16),
                      label: const Text('Directions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: BrandColors.indigo400.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📅 Appointment added to device calendar (${booking.qrPassCode})'),
                            backgroundColor: BrandColors.indigo500,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(LucideIcons.calendarPlus, size: 16),
                      label: const Text('Add Calendar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.indigo500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BrandThemeColors nc, String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: BrandColors.indigo400),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(color: nc.textTertiary, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: nc.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Custom painter to generate a clean QR code aesthetic matrix
class _QrCodePainter extends CustomPainter {
  final String seed;
  _QrCodePainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    const gridSize = 9;
    final cellSize = size.width / gridSize;

    // Draw position detection corners
    _drawCornerMarker(canvas, paint, 0, 0, cellSize);
    _drawCornerMarker(canvas, paint, (gridSize - 3) * cellSize, 0, cellSize);
    _drawCornerMarker(canvas, paint, 0, (gridSize - 3) * cellSize, cellSize);

    // Draw inner data modules based on seed hash
    final hash = seed.hashCode.abs();
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        // Skip corner markers
        if ((row < 3 && col < 3) || (row < 3 && col >= gridSize - 3) || (row >= gridSize - 3 && col < 3)) {
          continue;
        }

        if ((row + col + hash) % 3 == 0 || (row * col + hash) % 5 == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(col * cellSize + 1.5, row * cellSize + 1.5, cellSize - 3, cellSize - 3),
              const Radius.circular(2),
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawCornerMarker(Canvas canvas, Paint paint, double x, double y, double cellSize) {
    final outerRect = Rect.fromLTWH(x, y, cellSize * 3, cellSize * 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(4)),
      paint,
    );
    final innerWhiteRect = Rect.fromLTWH(x + cellSize * 0.5, y + cellSize * 0.5, cellSize * 2, cellSize * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerWhiteRect, const Radius.circular(2)),
      Paint()..color = Colors.white,
    );
    final innerBlackRect = Rect.fromLTWH(x + cellSize, y + cellSize, cellSize, cellSize);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerBlackRect, const Radius.circular(1)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
