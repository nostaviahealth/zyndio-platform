import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_state.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_view.dart';
import 'package:zyndio_patient/demo/widgets/footer_links.dart';

void main() {
  testWidgets('offline at 390x844 has no overflow and the footer sits at the bottom', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: SignInView(state: SignInState.offline())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final footerBottom = tester.getBottomLeft(find.byType(FooterLinks)).dy;
    expect(footerBottom, lessThanOrEqualTo(844));
    expect(footerBottom, greaterThan(844 - 120));
  });

  testWidgets('default (shortest content) at 390x844 also pins the footer to the bottom', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: SignInView(state: SignInState.defaultState())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final footerBottom = tester.getBottomLeft(find.byType(FooterLinks)).dy;
    expect(footerBottom, greaterThan(844 - 60));
  });
}
