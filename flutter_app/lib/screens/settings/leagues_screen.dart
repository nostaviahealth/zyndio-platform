import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/patient_provider.dart';
import '../../services/gamification_service.dart';
import '../../widgets/xp_coins_header.dart';

class LeaguesScreen extends ConsumerWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gState = ref.watch(gamificationProvider);
    final daysLeft = _calculateDaysRemaining();

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // Premium Glassy AppBar
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: context.nc.scaffoldBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.chevronLeft, color: context.nc.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'Leagues & Rewards',
                style: TextStyle(
                  color: context.nc.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // 1. Current League Podium
                  _LeagueHeroPodium(gState: gState, daysLeft: daysLeft),
                  const SizedBox(height: 48),

                  // 2. Badge Collection
                  const _SectionHeader(title: 'Badge Collection'),
                  const SizedBox(height: 20),
                  _BadgeCollectionGallery(badges: gState.badges),
                  const SizedBox(height: 48),

                  // 3. League RoadMap
                  const _SectionHeader(title: 'League Roadmap'),
                  const SizedBox(height: 24),
                  _LeagueRoadmap(currentLeague: gState.league),
                  const SizedBox(height: 48),

                  // 4. League Standings
                  const _SectionHeader(title: 'Clinic Standings'),
                  const SizedBox(height: 32),
                  const LeagueStandings(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateDaysRemaining() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return nextMonth.difference(now).inDays;
  }
}

/// Clinic leaderboard (top 10). The own-row highlight comes from the
/// server-set `is_me` flag (TC-026) - rows carry no user/patient ids.
class LeagueStandings extends ConsumerWidget {
  const LeagueStandings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(leagueStandingsProvider);

    return standingsAsync.when(
      data: (standings) {
        if (standings.isEmpty) {
          // TC-030 item 11 (Ava L1): sentence-case, readable empty copy in
          // textSecondary, replacing the all-caps "RECRUITING COMPETITORS...".
          return Center(
            child: Text(
              'No standings yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.nc.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        final limitedStandings = standings.take(10).toList();
        final top3 = limitedStandings.take(3).toList();
        final others = limitedStandings.skip(3).toList();

        return Column(
          children: [
            // TOP 3 PODIUM
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (top3.length > 1) Expanded(child: _buildPodiumUser(context, top3[1], 2, 70)),
                if (top3.length > 1) const SizedBox(width: 8),
                if (top3.isNotEmpty) Expanded(child: _buildPodiumUser(context, top3[0], 1, 90)),
                if (top3.length > 2) const SizedBox(width: 8),
                if (top3.length > 2) Expanded(child: _buildPodiumUser(context, top3[2], 3, 70)),
              ],
            ),
            const SizedBox(height: 40),

            // OTHERS LIST
            if (others.isNotEmpty)
              ...others.map((player) {
                final isMe = GamificationService.isLeaderboardSelf(player);
                final name = GamificationService.leaderboardDisplayName(player['name'] as String?);
                // TC-030 item 20: an anonymous OWN row is labelled by the "You"
                // pill alone, so it never reads "Anonymous, you".
                final youOnly = isMe && GamificationService.isLeaderboardAnonymous(player['name'] as String?);
                final rank = limitedStandings.indexOf(player) + 1;
                final xp = player['league_xp'];
                return Semantics(
                  // TC-030 item 0a (Ava): read the whole row once. excludeSemantics
                  // drops the per-child nodes (rank, name, "You" pill, XP) that
                  // otherwise made a screen reader announce the row twice; the
                  // single label carries rank, name, the "you" cue and XP.
                  excludeSemantics: true,
                  label: leaderboardRowLabel(rank: rank, name: name, xp: xp, isMe: isMe, youOnly: youOnly),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isMe ? context.nc.textPrimary.withValues(alpha: 0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      // Own-row border: a solid design-token blue (#2563EB) that
                      // clears WCAG 1.4.1 non-text contrast against both the page
                      // and the row tint, in light and dark (TC-030 item 0a, Ava).
                      border: Border.all(
                        color: isMe ? context.nc.leaderboardOwnBorder : Colors.transparent,
                        width: isMe ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '#${limitedStandings.indexOf(player) + 1}',
                          style: TextStyle(
                            color: isMe ? context.nc.textPrimary : context.nc.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildAvatarPlaceholder(context, player, 14),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            children: [
                              if (!youOnly) Flexible(
                                child: Text(
                                  name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMe ? context.nc.textPrimary : context.nc.textSecondary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (isMe) ...[
                                if (!youOnly) const SizedBox(width: 8),
                                const _YouPill(),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${player['league_xp']} XP',
                          // TC-030 item 11: theme secondary token for others
                          // (was invisible Colors.white38); own XP a success
                          // green that's AA on both surfaces.
                          style: TextStyle(
                            color: isMe ? _ownXpColor(context) : context.nc.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
      // TC-030 item 11 (Ava L1): a spinner tinted for the current theme (the
      // old Colors.white10 was invisible in light mode), and friendly error
      // copy instead of printing the raw exception.
      loading: () => Center(child: CircularProgressIndicator(color: context.nc.primary)),
      error: (e, s) => Center(
        child: Text(
          "Standings couldn't load. Pull to refresh or try again later.",
          textAlign: TextAlign.center,
          style: TextStyle(color: context.nc.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildPodiumUser(BuildContext context, Map<String, dynamic> player, int rank, double size) {
    final color = rank == 1 ? const Color(0xFFF59E0B) : (rank == 2 ? const Color(0xFF94A3B8) : const Color(0xFFCD7F32));
    final isMe = GamificationService.isLeaderboardSelf(player);
    final name = GamificationService.leaderboardDisplayName(player['name'] as String?);
    final youOnly = isMe && GamificationService.isLeaderboardAnonymous(player['name'] as String?);
    final xp = player['league_xp'];

    return Semantics(
      // TC-030 item 0a (Ava): one label per podium row - rank, name, the "you"
      // cue and XP - with excludeSemantics so the child Texts/pill aren't read a
      // second time (WCAG: no colour-only cue, and no duplicated announcement).
      excludeSemantics: true,
      label: leaderboardRowLabel(rank: rank, name: name, xp: xp, isMe: isMe, youOnly: youOnly),
      child: Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow
            Container(
              width: size + 20,
              height: size + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 5),
                ],
              ),
            ),
            // Avatar Ring - a 2px brand-primary ring marks the caller's own
            // avatar (TC-030 item 0a); everyone else keeps the medal-tinted ring.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMe ? context.nc.primary : color.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: _buildAvatarPlaceholder(context, player, size / 2),
            ),
            // Rank Badge
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // TC-030 item 20: an anonymous own podium row shows the "You" pill
        // (below) as its only label, never "ANONYMOUS".
        if (!youOnly) Text(
          name.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMe ? context.nc.textPrimary : context.nc.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: rank == 1 ? 13 : 11,
            letterSpacing: 0.5,
          ),
        ),
        // Non-colour "You" cue under the own podium avatar (TC-030 item 0a).
        if (isMe) ...[
          if (!youOnly) const SizedBox(height: 6),
          const _YouPill(),
        ],
        const SizedBox(height: 4),
        Text(
          '${player['league_xp']} XP',
          // TC-030 item 11: XP in textSecondary for AA; the medal colour stays
          // on the rank badge only, where it has enough area to carry it.
          style: TextStyle(
            color: context.nc.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: rank == 1 ? 11 : 10,
          ),
        ),
      ],
    ),
    );
  }
}

/// Screen-reader label for one leaderboard row (TC-030 items 0a and 20):
///   * another patient: "#n, Jordan R., 400 XP" or "#n, Anonymous, 400 XP";
///   * the caller's own named row: "#n, Jordan R., you, 400 XP" (unchanged);
///   * the caller's own ANONYMOUS row: "#n, You, 400 XP". The "You" pill is the
///     row's main (and only visible) label there, so the row never reads
///     "Anonymous, you" - the patient knows who they are, and "Anonymous" would
///     only describe how OTHER patients see them.
@visibleForTesting
String leaderboardRowLabel({
  required int rank,
  required String name,
  required Object? xp,
  required bool isMe,
  required bool youOnly,
}) {
  if (youOnly) return '#$rank, You, $xp XP';
  return isMe ? '#$rank, $name, you, $xp XP' : '#$rank, $name, $xp XP';
}

/// Own-row XP colour (TC-030 item 11): a success green that meets AA on both
/// surfaces - #047857 on the light page, a lighter #34D399 on the dark page.
Color _ownXpColor(BuildContext context) =>
    context.nc.isDark ? const Color(0xFF34D399) : const Color(0xFF047857);

/// Small "You" pill used as the leaderboard's non-colour own-row cue
/// (TC-030 item 0a). Brand-tinted chip with the literal word, so the
/// highlight doesn't depend on colour alone (WCAG 1.4.1).
class _YouPill extends StatelessWidget {
  const _YouPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.nc.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.nc.primary.withValues(alpha: 0.7)),
      ),
      child: Text(
        'You',
        style: TextStyle(
          // >=4.5:1 on the brand tint in both modes (TC-030 item 0a, Ava); the
          // old context.nc.primary was 2.71:1 in light / 4.21:1 in dark.
          color: context.nc.leaderboardYouPillText,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LeagueHeroPodium extends ConsumerWidget {
  final GamificationState gState;
  final int daysLeft;

  const _LeagueHeroPodium({required this.gState, required this.daysLeft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = gState.league;
    final nextLeague = league == League.legendary ? null : League.values[league.index + 1];
    final profile = ref.watch(patientProfileProvider).value;

    return Column(
      children: [
        // Bio-Sync Avatar Centerpiece
        Stack(
          alignment: Alignment.center,
          children: [
            // Background Spectral Energy
            AnimatedSpectralOrb(
              colors: league.gradient,
              size: 180,
            ),
            // High-Fidelity Avatar
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                boxShadow: [
                  BoxShadow(color: league.color.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 5),
                ],
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundImage: _getAvatarProvider(profile?.avatarUrl),
                backgroundColor: Colors.white10,
                child: profile?.avatarUrl == null ? Icon(LucideIcons.user, size: 40, color: context.nc.textTertiary) : null,
              ),
            ),
            // League Badge (Floating)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: league.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: league.color.withValues(alpha: 0.5), blurRadius: 20),
                  ],
                ),
                child: Text(
                  'RANK #1', // Static placeholder or calculated
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(
          league.displayName.toUpperCase(),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 8.0,
            shadows: [
              Shadow(color: league.color.withValues(alpha: 0.5), blurRadius: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: league.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: league.color.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: league.color.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: -5),
            ],
          ),
          child: Text(
            '$daysLeft DAYS UNTIL RESET',
            style: TextStyle(
              color: league.color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 60),
        // Progress Glass Card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      league.color.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildProgressStat(context, 'CURRENT XP', gState.leagueXp, league.color),
                        if (nextLeague != null)
                          _buildProgressStat(context, 'NEXT TIER', nextLeague.threshold, nextLeague.color, isRight: true),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Stack(
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: gState.leagueProgress),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutQuart,
                          builder: (context, value, child) {
                            return FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [league.color.withValues(alpha: 0.6), league.color],
                                  ),
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: [
                                    BoxShadow(color: league.color.withValues(alpha: 0.6), blurRadius: 12),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStat(BuildContext context, String label, int value, Color color, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.0),
        ),
        const SizedBox(height: 8),
        AnimatedCounter(
          value: value,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: context.nc.textPrimary, letterSpacing: 1.0),
        ),
      ],
    );
  }
}

class _BadgeCollectionGallery extends StatelessWidget {
  final Map<String, int> badges;

  const _BadgeCollectionGallery({required this.badges});

  @override
  Widget build(BuildContext context) {
    final collectionLeagues = League.values.where((l) => l != League.bronze).toList();

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: collectionLeagues.length,
        itemBuilder: (context, index) {
          final league = collectionLeagues[index];
          final count = badges[league.name] ?? 0;
          final isUnlocked = count > 0;

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isUnlocked ? league.color.withOpacity(0.12) : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isUnlocked ? league.color.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        isUnlocked ? league.color.withOpacity(0.1) : Colors.transparent,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mini Living Orb
                      AnimatedSpectralOrb(
                        colors: league.gradient,
                        size: 56,
                        isUnlocked: isUnlocked,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        league.displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isUnlocked ? context.nc.textPrimary : context.nc.textTertiary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (isUnlocked) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: league.color.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: league.color.withOpacity(0.5), blurRadius: 8),
                            ],
                          ),
                          child: Text(
                            'x$count',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeagueRoadmap extends StatelessWidget {
  final League currentLeague;

  const _LeagueRoadmap({required this.currentLeague});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: League.values.map((league) {
        final isCurrent = league == currentLeague;
        final isPast = league.index < currentLeague.index;
        final isUnlocked = isCurrent || isPast;

        return IntrinsicHeight(
          child: Stack(
            children: [
              // ── Horizontal Connector (Background Layer) ──
              Positioned(
                left: 24, // Start from center of the spine/orb
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 56, // 24 (spine center) + 32 (bridge width)
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1.5),
                      gradient: LinearGradient(
                        colors: [
                          isUnlocked ? league.color.withOpacity(0.8) : context.nc.divider.withOpacity(0.1),
                          isUnlocked ? league.color.withOpacity(0.2) : Colors.transparent,
                        ],
                      ),
                      boxShadow: isUnlocked ? [
                        BoxShadow(
                          color: league.color.withOpacity(0.2),
                          blurRadius: 4,
                        )
                      ] : null,
                    ),
                  ),
                ),
              ),
              
              // ── Content Layer ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Glowing Roadmap Spine
                  SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              gradient: league == League.bronze 
                                  ? null 
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color.lerp(League.values[league.index - 1].color, league.color, 0.5)!.withOpacity(isUnlocked ? 0.4 : 0.05),
                                        league.color.withOpacity(isUnlocked ? 0.4 : 0.05),
                                      ],
                                    ),
                              color: league == League.bronze ? Colors.transparent : null,
                            ),
                          ),
                        ),
                        AnimatedSpectralOrb(
                          colors: league.gradient,
                          size: isCurrent ? 40 : 28,
                          isUnlocked: isUnlocked,
                        ),
                        Expanded(
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              gradient: league == League.legendary 
                                  ? null 
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        league.color.withOpacity(isPast ? 0.4 : 0.05),
                                        Color.lerp(league.color, League.values[math.min(league.index + 1, League.values.length - 1)].color, 0.5)!.withOpacity(isPast ? 0.4 : 0.05),
                                      ],
                                    ),
                              color: league == League.legendary ? Colors.transparent : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 2. Connector Spacer (The line is in the Stack background)
                  const SizedBox(width: 32),

                  // 3. Tier Card
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isCurrent ? [
                          BoxShadow(
                            color: league.color.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: -5,
                          )
                        ] : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                            decoration: BoxDecoration(
                              color: isUnlocked 
                                  ? league.color.withOpacity(isCurrent ? 0.15 : 0.08)
                                  : Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isCurrent 
                                    ? league.color.withOpacity(0.5) 
                                    : Colors.white.withOpacity(isUnlocked ? 0.15 : 0.05),
                                width: isCurrent ? 1.5 : 1.0,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  isUnlocked ? league.color.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      league.displayName.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: isUnlocked 
                                            ? context.nc.textPrimary 
                                            : Colors.white.withOpacity(0.3),
                                        fontSize: 15,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    if (!isUnlocked)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'LOCKED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white.withOpacity(0.4),
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                if (isCurrent)
                                  _ActiveBadge(color: league.color)
                                else if (!isPast)
                                  Text(
                                    '${league.threshold} XP',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  )
                                else
                                  Icon(LucideIcons.checkCircle2, color: league.color, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final Color color;
  const _ActiveBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      'ACTIVE',
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: context.nc.textTertiary,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: context.nc.divider.withValues(alpha: 0.05))),
      ],
    );
  }
}

Widget _buildAvatarPlaceholder(BuildContext context, Map<String, dynamic> player, double radius) {
  final provider = _getAvatarProvider(player['avatar_url'] as String?);
  if (provider != null) {
    // Only the caller's own row keeps a photo (TC-030 item 9); every other row
    // has a null avatar_url and falls through to initials below.
    return CircleAvatar(
      radius: radius,
      backgroundImage: provider,
      backgroundColor: context.nc.textPrimary.withOpacity(0.05),
    );
  }

  // TC-030 item 20 (Ava): an anonymous row shows the Lucide `user` glyph (not
  // '?' or 'A'), on the same tint and in the same textSecondary colour as the
  // initials. 20px at the 28px list avatar (radius 14), scaled the same way
  // on the podium. Lucide icons: ISC licence (lucide.dev); the
  // lucide_icons_flutter package that ships them: MIT. Decorative: the row's
  // Semantics label already says "Anonymous" / "You".
  // One tint for both placeholders (glyph and initials).
  final placeholderTint = context.nc.textPrimary.withValues(alpha: 0.06);
  if (GamificationService.isLeaderboardAnonymous(player['name'] as String?)) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: placeholderTint,
      child: Icon(
        LucideIcons.user,
        key: const ValueKey('leaderboard-anonymous-glyph'),
        size: radius * 10 / 7,
        color: context.nc.textSecondary,
      ),
    );
  }

  // No photo: render the name's initials, not a generic person icon (TC-030
  // item 9, Ava). Initials use textSecondary on a subtle tint, which clears AA
  // (>=4.5:1) in both modes - light #475569 ~7.2:1, dark #CBD5E1 ~13:1.
  final initials = GamificationService.leaderboardDisplayInitials(player['name'] as String?);
  return CircleAvatar(
    radius: radius,
    backgroundColor: placeholderTint,
    child: Text(
      initials,
      style: TextStyle(
        color: context.nc.textSecondary,
        fontWeight: FontWeight.w900,
        fontSize: radius * 0.8,
        letterSpacing: 0,
      ),
    ),
  );
}

ImageProvider? _getAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('data:image')) {
    try {
      final base64String = avatarUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return null;
    }
  }
  return NetworkImage(avatarUrl);
}
