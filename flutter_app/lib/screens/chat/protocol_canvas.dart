import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/health_protocol.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';

class ProtocolCanvas extends StatelessWidget {
  final HealthProtocol protocol;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const ProtocolCanvas({
    super.key,
    required this.protocol,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Container(
        decoration: BoxDecoration(
          color: context.nc.scaffoldBg, // Apple System Grouped Background
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle (Apple Style)
            Container(
              height: 24,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.nc.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            // Padding between drag handle and header
            Container(color: context.nc.cardSurface, height: 12),
          
          Expanded(
            child: CustomScrollView(
              slivers: [
                _buildHeader(context),
                _buildSummaryParams(context),
                _buildSection(context, "LIFESTYLE", protocol.lifestyle),
                _buildSection(context, "NUTRITION", protocol.diet),
                _buildSection(context, "TRAINING", protocol.fitness),
                _buildSection(context, "SUPPLEMENTS", protocol.supplements),
                _buildCitations(context),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          _buildBottomBar(context),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: context.nc.cardSurface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "AI PROTOCOL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F46E5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.nc.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.x, size: 18, color: context.nc.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              protocol.title,
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.nc.textPrimary,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              protocol.summary,
              style: TextStyle(
                fontSize: 16,
                color: context.nc.textSecondary,
                height: 1.5,
                letterSpacing: -0.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryParams(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: context.nc.cardSurface,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        margin: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            _paramBadge(context, LucideIcons.calendar, "Coming Soon"), // Placeholder for Duration
            const SizedBox(width: 12),
            _paramBadge(context, LucideIcons.tag, protocol.type),
          ],
        ),
      ),
    );
  }

  Widget _paramBadge(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.nc.inputFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8E8E93)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.nc.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String header, ProtocolSection section) {
    if (section.content.isEmpty && section.actionItems.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  header,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.nc.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.nc.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.nc.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Intro
                if (section.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title, 
                          style: GoogleFonts.outfit(
                            fontSize: 19, 
                            fontWeight: FontWeight.w700, 
                            color: context.nc.textPrimary, 
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.content, 
                          style: TextStyle(
                            fontSize: 15, 
                            color: context.nc.textSecondary, 
                            height: 1.5, 
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (section.content.isNotEmpty && section.actionItems.isNotEmpty)
                   Divider(height: 1, color: context.nc.divider),

                // Action Items List
                if (section.actionItems.isNotEmpty)
                  ...section.actionItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isLast = index == section.actionItems.length - 1;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item, 
                                  style: TextStyle(
                                    fontSize: 15, 
                                    color: context.nc.textPrimary, 
                                    height: 1.5, 
                                    letterSpacing: -0.2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast) Divider(height: 1, indent: 40, color: context.nc.divider),
                      ],
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        border: Border(top: BorderSide(color: context.nc.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: const Color(0xFF10B981), // Zyndio Emerald
              onPressed: () {
                HapticFeedback.mediumImpact();
                onSave();
              },
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.save, size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Save Protocol", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitations(BuildContext context) {
    if (protocol.citations.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.nc.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.nc.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.bookOpen, size: 16, color: context.nc.textTertiary),
                const SizedBox(width: 8),
                Text(
                  "CLINICAL EVIDENCE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...protocol.citations.map((citation) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("•", style: TextStyle(color: context.nc.textTertiary, fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      citation,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.nc.textSecondary,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 4),
            Text(
              "Protocol generated by Zyndio Intelligence based on combined analysis of clinical literature and individual biomarker telemetry.",
              style: TextStyle(
                fontSize: 10,
                color: context.nc.textTertiary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
