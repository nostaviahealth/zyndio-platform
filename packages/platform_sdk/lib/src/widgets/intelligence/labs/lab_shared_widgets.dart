import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/lab_report.dart';

class BrandStatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;

  const BrandStatPill({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandBiomarkerCard extends StatefulWidget {
  final LabMarker marker;
  final VoidCallback? onDeepDive;

  const BrandBiomarkerCard({
    super.key,
    required this.marker,
    this.onDeepDive,
  });

  @override
  State<BrandBiomarkerCard> createState() => _BrandBiomarkerCardState();
}

class _BrandBiomarkerCardState extends State<BrandBiomarkerCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (widget.marker.isOptimal) {
      statusColor = const Color(0xFF10B981);
    } else if (widget.marker.isInRange) {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFFEF4444);
    }

    final unit = widget.marker.unit.isNotEmpty 
        ? widget.marker.unit 
        : (widget.marker.range.contains('mg/dL') ? 'mg/dL' : (widget.marker.range.contains('%') ? '%' : ''));

    return GestureDetector(
      onTap: () => setState(() => isExpanded = !isExpanded),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.marker.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: BrandColors.dark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.marker.displayStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.marker.value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (unit.isNotEmpty)
                        Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: BrandColors.slate500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: BrandColors.slate400,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: BrandColors.slate200),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Reference Range", style: TextStyle(fontSize: 11, color: BrandColors.slate500)),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              widget.marker.range,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BrandColors.slate700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Category", style: TextStyle(fontSize: 11, color: BrandColors.slate500)),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              widget.marker.category,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: BrandColors.slate700),
                            ),
                          ),
                        ],
                      ),
                      if (widget.marker.labName != null && widget.marker.labName!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Source Lab", style: TextStyle(fontSize: 11, color: BrandColors.slate500)),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Text(
                                widget.marker.labName!,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, color: BrandColors.slate700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onDeepDive != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: widget.onDeepDive,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "AI Insight",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    ),
                  )
                ]
              ],
            ],
          ),
        ),
      ),
    );
  }
}
