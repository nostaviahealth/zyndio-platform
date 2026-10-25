import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../providers/intelligence_provider.dart';
import '../../providers/patient_provider.dart';

class DigitalTwinScreen extends ConsumerStatefulWidget {
  const DigitalTwinScreen({super.key});

  @override
  ConsumerState<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends ConsumerState<DigitalTwinScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientName = ref.watch(patientProfileProvider).value?.name?.split(' ').first ?? 'User';
    final wearable = ref.watch(wearableStateProvider).value;
    final intelligence = ref.watch(intelligenceDataProvider).value;

    final heartRate = wearable?.rhr ?? 72;
    final sleepScore = wearable?.sleepScore ?? 88;
    final activitySteps = wearable?.steps ?? 9450;
    final stressScore = wearable?.stressScore ?? 22;
    
    final overallHealth = intelligence?.overallScore ?? 92;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF020617), // Deep space blue/black
        body: Stack(
          children: [
            // Ambient Background
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.2,
                      left: -50,
                      child: _buildAuroraBlob(BrandColors.blue500, 0.15 + 0.05 * _pulseController.value),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.5,
                      right: -100,
                      child: _buildAuroraBlob(BrandColors.purple500, 0.1 + 0.05 * _pulseController.value),
                    ),
                    Positioned(
                      bottom: -50,
                      left: MediaQuery.of(context).size.width * 0.2,
                      child: _buildAuroraBlob(BrandColors.emerald500, 0.1 + 0.05 * _pulseController.value),
                    ),
                  ],
                );
              },
            ),
            
            // Grid Lines
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
                          ),
                        ),
                        const Column(
                          children: [
                            Text(
                              "DIGITAL TWIN",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
                            Text(
                              "SYSTEM STATUS: OPTIMAL",
                              style: TextStyle(color: BrandColors.emerald400, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
                            ),
                          ],
                        ),
                        const SizedBox(width: 40), // Balance the back button
                      ],
                    ),
                  ),
                  
                  // Top Status
                  const SizedBox(height: 10),
                  Text(
                    "GOOD ${DateTime.now().hour < 12 ? 'MORNING' : (DateTime.now().hour < 17 ? 'AFTERNOON' : 'EVENING')}, ${patientName.toUpperCase()}!",
                    style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.activity, color: BrandColors.blue400, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        "HEALTH INDEX: $overallHealth/100",
                        style: const TextStyle(color: BrandColors.blue400, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  
                  // Central Body
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Holographic Body Outline
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: double.infinity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return ColorFiltered(
                                      colorFilter: const ColorFilter.matrix([
                                        1, 0, 0, 0, 0,
                                        0, 1, 0, 0, 0,
                                        0, 0, 1, 0, 0,
                                        0.33, 0.5, 0.16, 0, 0,
                                      ]),
                                      child: Image.asset(
                                        'assets/images/digital_twin.png',
                                        width: MediaQuery.of(context).size.width * 0.85,
                                        height: 550,
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  }
                              ),
                              // Heart Node
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) => Positioned(
                                  top: 155,
                                  left: MediaQuery.of(context).size.width * 0.5 + 12, // Anatomical left (right side of center)
                                  child: _buildGlowingNode(BrandColors.red500, _pulseController.value),
                                ),
                              ),
                              // Brain Node
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) => Positioned(
                                  top: 30,
                                  left: MediaQuery.of(context).size.width * 0.5 - 6, // Center
                                  child: _buildGlowingNode(BrandColors.purple400, _pulseController.value),
                                ),
                              ),
                              // Gut/Stomach Node
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) => Positioned(
                                  top: 265,
                                  left: MediaQuery.of(context).size.width * 0.5 - 6, // Center
                                  child: _buildGlowingNode(BrandColors.emerald400, _pulseController.value),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Floating Data Tags
                        Positioned(
                          top: 60,
                          left: 20,
                          child: _buildDataTag("Heart Rate", "$heartRate bpm", BrandColors.red400),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: _buildDataTag("Sleep Score", "$sleepScore", BrandColors.purple400),
                        ),
                        Positioned(
                          top: 240,
                          right: 20,
                          child: _buildDataTag("Stress Level", "$stressScore%", BrandColors.amber400),
                        ),
                        Positioned(
                          bottom: 40,
                          left: 20,
                          child: _buildDataTag("Activity", "$activitySteps steps", BrandColors.emerald400),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Analytics Cards (Bento style)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Row(
                      children: [
                        Expanded(child: _buildBottomCard(LucideIcons.heartPulse, "VITALS", "Heart Rate:", "$heartRate bpm", BrandColors.red400)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildBottomCard(LucideIcons.moon, "SLEEP", "Score:", "$sleepScore", BrandColors.purple400)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildBottomCard(LucideIcons.activity, "ACTIVITY", "Steps:", "$activitySteps", BrandColors.emerald400)),
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

  Widget _buildGlowingNode(Color color, double pulse) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5 + 0.5 * pulse),
            blurRadius: 10 + 10 * pulse,
            spreadRadius: 2 + 5 * pulse,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildAuroraBlob(Color color, double opacity) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    ).blur(100);
  }

  Widget _buildDataTag(String label, String value, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 1,
          color: accentColor.withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildBottomCard(IconData icon, String title, String subLabel, String value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Text(subLabel, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1;

    final cellWidth = 30.0;
    
    // Draw vertical lines
    for (double x = 0; x <= size.width; x += cellWidth) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += cellWidth) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension BlurExtension on Widget {
  Widget blur(double sigma) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: this,
    );
  }
}
