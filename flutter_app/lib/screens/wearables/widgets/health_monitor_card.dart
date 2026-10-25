import 'package:flutter/material.dart';
import 'dashboard_card_style.dart';
import '../../../config/theme.dart';

enum MetricState { higher, lower, normal, noData }

/// A single health metric card for the Health Monitor grid.
/// Matches the WHOOP reference: icon + label top, large value + unit,
/// status badge (Normal/Higher/Lower), and a dynamic gauge slider.
class HealthMonitorCard extends StatelessWidget {
  final String label;
  final String valueStr;
  final String unit;
  final IconData icon;
  final double? numericValue;
  
  // Optimization boundaries for the gauge slider
  final double minBound;    // Very bottom of the slider
  final double maxBound;    // Very top of the slider
  final double normalMin;   // Bottom white dash
  final double normalMax;   // Top white dash

  // Colors mapping
  final Color higherColor;
  final Color lowerColor;
  final Color normalColor;

  final VoidCallback? onTap;

  const HealthMonitorCard({
    super.key,
    required this.label,
    required this.valueStr,
    required this.unit,
    required this.icon,
    this.numericValue,
    required this.minBound,
    required this.maxBound,
    required this.normalMin,
    required this.normalMax,
    this.higherColor = const Color(0xFFF97316), // Orange
    this.lowerColor = const Color(0xFF3B82F6),  // Blue
    this.normalColor = const Color(0xFF10B981), // Green
    this.onTap,
  });

  MetricState get _state {
    if (numericValue == null) return MetricState.noData;
    if (numericValue! > normalMax) return MetricState.higher;
    if (numericValue! < normalMin) return MetricState.lower;
    return MetricState.normal;
  }

  Color get _statusColor {
    switch (_state) {
      case MetricState.higher:
        return higherColor;
      case MetricState.lower:
        return lowerColor;
      case MetricState.normal:
        return normalColor;
      case MetricState.noData:
        return const Color(0xFF94A3B8); // Slate cool grey
    }
  }

  IconData get _statusIcon {
    switch (_state) {
      case MetricState.higher:
        return Icons.arrow_upward_rounded;
      case MetricState.lower:
        return Icons.arrow_downward_rounded;
      case MetricState.normal:
        return Icons.check_circle_rounded;
      case MetricState.noData:
        return Icons.remove_circle_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (_state) {
      case MetricState.higher:
        return 'Higher';
      case MetricState.lower:
        return 'Lower';
      case MetricState.normal:
        return 'Normal';
      case MetricState.noData:
        return 'No data';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = _state != MetricState.noData;
    final color = _statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Row(
          children: [
            // Left content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon + Label
                  Row(
                    children: [
                      Icon(icon, size: 16, color: context.nc.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.nc.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Value + Unit
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: valueStr,
                              style: TextStyle(
                                fontSize: hasData && valueStr.length > 5 ? 24 : 28,
                                fontWeight: FontWeight.w500,
                                color: hasData ? context.nc.textPrimary : context.nc.textTertiary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (hasData)
                              TextSpan(
                                text: ' $unit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: context.nc.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status badge
                  Row(
                    children: [
                      Icon(_statusIcon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right Gauge Slider
            _buildGauge(color),
          ],
        ),
      ),
    );
  }

  Widget _buildGauge(Color activeColor) {
    // Determine the percentage fill from bottom (0.0) to top (1.0)
    double percentFill = 0;
    if (numericValue != null) {
      if (maxBound == minBound) {
        percentFill = 0.5;
      } else {
        percentFill = (numericValue! - minBound) / (maxBound - minBound);
      }
      percentFill = percentFill.clamp(0.0, 1.0);
    }

    // Determine position of the normal dashes
    double normalMinPercent = (normalMin - minBound) / (maxBound - minBound);
    double normalMaxPercent = (normalMax - minBound) / (maxBound - minBound);
    normalMinPercent = normalMinPercent.clamp(0.0, 1.0);
    normalMaxPercent = normalMaxPercent.clamp(0.0, 1.0);

    const double trackWidth = 10.0;
    const double thumbSize = 18.0;

    return Container(
      width: thumbSize,
      margin: const EdgeInsets.only(left: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;

          if (numericValue == null) {
            // Empty grey track for no data
            return Center(
              child: Container(
                width: trackWidth,
                height: height,
                decoration: BoxDecoration(
                  color: context.nc.textTertiary.withOpacity(0.1), // Dynamic background
                  borderRadius: BorderRadius.circular(trackWidth / 2),
                ),
              ),
            );
          }

          // Active track logic
          final absoluteFillHeight = height * percentFill;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Background track
              Container(
                width: trackWidth,
                height: height,
                decoration: BoxDecoration(
                  color: context.nc.textTertiary.withOpacity(0.1), // Lighter background
                  borderRadius: BorderRadius.circular(trackWidth / 2),
                  border: Border.all(color: Colors.white.withOpacity(0.03), width: 1),
                ),
              ),
              // Filled track (from bottom up) with gradient
              Positioned(
                bottom: 0,
                child: Container(
                  width: trackWidth,
                  height: absoluteFillHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        activeColor.withOpacity(0.4),
                        activeColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(trackWidth / 2),
                  ),
                ),
              ),
              // Normal Min Dash
              Positioned(
                bottom: height * normalMinPercent,
                child: Container(
                  width: trackWidth - 2,
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Normal Max Dash
              Positioned(
                bottom: height * normalMaxPercent,
                child: Container(
                  width: trackWidth - 2,
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Thumb marker (Sleeker white circle with thin border)
              Positioned(
                bottom: absoluteFillHeight - (thumbSize / 2),
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeColor,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
