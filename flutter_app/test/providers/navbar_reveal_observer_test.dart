import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/providers/navbar_provider.dart';

/// A page that hides the tab bar the way Health Data does: on scroll down.
class _HidesOnScroll extends ConsumerWidget {
  const _HidesOnScroll();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          if ((n.scrollDelta ?? 0) > 3) ref.read(navbarVisibleProvider.notifier).hide();
          return false;
        },
        child: ListView(
          key: const Key('detail-list'),
          children: [for (var i = 0; i < 60; i++) SizedBox(height: 80, child: Text('Row $i'))],
        ),
      ),
    );
  }
}

/// Stands in for a tab's root screen: its own navigator, like a shell branch.
Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      navigatorObservers: [NavbarRevealObserver(container.read(navbarVisibleProvider.notifier).show)],
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _HidesOnScroll())),
              child: const Text('open detail'),
            ),
            TextButton(
              onPressed: () => showDialog<void>(context: context, builder: (_) => const AlertDialog(title: Text('dialog'))),
              child: const Text('open dialog'),
            ),
          ]),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('leaving a page that hid the tab bar on scroll shows it again', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('detail-list')), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(container.read(navbarVisibleProvider), isFalse, reason: 'scrolling down hides the bar');

    // Back (the same pop the iOS swipe-back gesture performs).
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(container.read(navbarVisibleProvider), isTrue);
  });

  testWidgets('closing a dialog does not reveal a tab bar a page keeps hidden', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    container.read(navbarVisibleProvider.notifier).hide();

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);

    expect(container.read(navbarVisibleProvider), isFalse);
  });

  testWidgets('a page that hides the bar when it opens still wins over its own push', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorObservers: [NavbarRevealObserver(container.read(navbarVisibleProvider.notifier).show)],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _HidesOnOpen())),
            child: const Text('open chat'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open chat'));
    await tester.pumpAndSettle();

    expect(container.read(navbarVisibleProvider), isFalse);
  });
}

/// Hides the bar after its first frame, like the AI companion and food log.
class _HidesOnOpen extends ConsumerStatefulWidget {
  const _HidesOnOpen();

  @override
  ConsumerState<_HidesOnOpen> createState() => _HidesOnOpenState();
}

class _HidesOnOpenState extends ConsumerState<_HidesOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(navbarVisibleProvider.notifier).hide();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('chat'));
}
