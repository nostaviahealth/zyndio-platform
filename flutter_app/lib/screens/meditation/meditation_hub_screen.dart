import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/meditation_state_provider.dart';
import '../../providers/navbar_provider.dart';
import '../../services/audio_engine.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MeditationHubScreen extends ConsumerStatefulWidget {
  const MeditationHubScreen({super.key});

  @override
  ConsumerState<MeditationHubScreen> createState() => _MeditationHubScreenState();
}

class _MeditationHubScreenState extends ConsumerState<MeditationHubScreen> with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breatheAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );

    // Hide navbar for immersive meditation experience
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(navbarVisibleProvider.notifier).hide();
        // Warm up the audio engine (generates WAV files if missing)
        AudioEngine().init();
      }
    });
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;
    final state = ref.watch(meditationProvider);
    final notifier = ref.read(meditationProvider.notifier);
    
    final progress = state.remainingSeconds / (state.selectedMinutes * 60);

    if (state.isRunning && !_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
      WakelockPlus.enable();
    } else if (!state.isRunning && _breatheController.isAnimating) {
      _breatheController.stop();
      WakelockPlus.disable();
    }

    // Visual confirmation when session completes
    ref.listen(meditationProvider.select((s) => s.remainingSeconds), (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session Saved to Stats'),
            backgroundColor: nc.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Restore navbar immediately when popping starts
        ref.read(navbarVisibleProvider.notifier).show();
      },
      child: Scaffold(
        backgroundColor: nc.scaffoldBg,
        body: Stack(
          children: [
            // Background Glows
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nc.primary.withOpacity(0.04),
                ),
              ).blur(120),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(nc, context),
                  const Spacer(),
                  
                  // 1. Digital Timer Display
                  ScaleTransition(
                    scale: _breatheAnimation,
                    child: _buildTimerCircle(progress, nc, state),
                  ),
                  
                  const Spacer(),
                  
                  // 2. Preset Selection
                  if (!state.isRunning) _buildPresets(nc, state, notifier),
                  
                  const SizedBox(height: 64),
                  
                  // 3. Primary Action Button
                  _buildMainActionButton(nc, state, notifier),
                  
                  const SizedBox(height: 24),
                  
                  // 4. Subtle Atmosphere Toggle
                  _buildAtmosphereToggle(nc, state, notifier),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BrandThemeColors nc, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(LucideIcons.chevronLeft, color: nc.textPrimary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MINDFULNESS',
                  style: TextStyle(
                    color: nc.textSecondary.withOpacity(0.4),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Meditation',
                  style: TextStyle(
                    color: nc.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/settings/meditation_stats'),
            icon: Icon(LucideIcons.barChart2, color: nc.textSecondary.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCircle(double progress, BrandThemeColors nc, MeditationState state) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: CircularProgressIndicator(
              value: state.isRunning ? progress : 1.0,
              strokeWidth: 2.5,
              color: nc.primary,
              backgroundColor: nc.textSecondary.withOpacity(0.04),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(state.remainingSeconds),
                style: TextStyle(
                  color: nc.textPrimary,
                  fontSize: 80,
                  fontWeight: FontWeight.w200,
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -3,
                ),
              ),
              if (state.isRunning)
                Text(
                  'BREATHE',
                  style: TextStyle(
                    color: nc.textSecondary.withOpacity(0.4),
                    fontSize: 11,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w300,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresets(BrandThemeColors nc, MeditationState state, MeditationNotifier notifier) {
    return Column(
      children: [
        Text(
          'SELECT DURATION',
          style: TextStyle(
            color: nc.textSecondary.withOpacity(0.3),
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [5, 10, 15, 30, 45, 60].map((m) {
            final isSelected = state.selectedMinutes == m;
            return GestureDetector(
              onTap: () {
                notifier.setDuration(m);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? nc.primary.withOpacity(0.12) : nc.textSecondary.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? nc.primary.withOpacity(0.3) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  '$m min',
                  style: TextStyle(
                    color: isSelected ? nc.primary : nc.textSecondary.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMainActionButton(BrandThemeColors nc, MeditationState state, MeditationNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: GestureDetector(
        onTap: () => notifier.toggleTimer(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: state.isRunning ? nc.textSecondary.withOpacity(0.05) : nc.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (!state.isRunning)
                BoxShadow(
                  color: nc.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Center(
            child: Text(
              state.isRunning ? 'PAUSE SESSION' : 'START MEDITATION',
              style: TextStyle(
                color: state.isRunning ? nc.textPrimary : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAtmosphereToggle(BrandThemeColors nc, MeditationState state, MeditationNotifier notifier) {
    return GestureDetector(
      onTap: () => notifier.toggleAtmosphere(),
      child: Opacity(
        opacity: 0.8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.isAtmosphereActive ? LucideIcons.wind : LucideIcons.volumeX,
              color: state.isAtmosphereActive ? nc.primary : nc.textSecondary.withOpacity(0.4),
              size: 14,
            ),
            const SizedBox(width: 10),
            Text(
              state.isAtmosphereActive ? 'NEURAL ENGINE ACTIVE' : 'SILENT SYNC',
              style: TextStyle(
                color: state.isAtmosphereActive ? nc.primary : nc.textSecondary.withOpacity(0.4),
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

extension _BlurExtension on Widget {
  Widget blur(double sigma) {
    return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: this);
  }
}
