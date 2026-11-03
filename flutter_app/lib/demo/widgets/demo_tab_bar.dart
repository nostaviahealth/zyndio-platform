import 'package:flutter/material.dart';

import '../../config/theme.dart';

enum DemoTab { today, labs, log, zyndioAi, profile }

const Map<DemoTab, (String, IconData)> _tabs = {
  DemoTab.today: ('Today', Icons.home_outlined),
  DemoTab.labs: ('Labs', Icons.science_outlined),
  DemoTab.log: ('Log', Icons.description_outlined),
  DemoTab.zyndioAi: ('Zyndio AI', Icons.chat_bubble_outline),
  DemoTab.profile: ('Profile', Icons.person_outline),
};

/// C34 Tab bar: 390x83 (49 content + 34 home-indicator inset), 5 equal tabs.
/// Selection is colour + an explicit announced state, never colour alone.
class DemoTabBar extends StatelessWidget {
  const DemoTabBar({super.key, required this.selected});

  final DemoTab selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(top: ZyndioSpace.s8),
        child: Row(
          children: [
            for (final tab in DemoTab.values) Expanded(child: _TabItem(tab: tab, selected: tab == selected)),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected});

  final DemoTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final (label, icon) = _tabs[tab]!;
    final color = selected ? colors.brandPrimary : colors.textTertiary;
    return Semantics(
      label: label,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ZyndioSize.touchMin, minWidth: ZyndioSize.touchMin),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: ZyndioSize.icon, color: color),
              const SizedBox(height: ZyndioSpace.s4 - 2),
              Text(
                label,
                style: ZyndioType.caption.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
