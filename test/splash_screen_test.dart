import 'package:ciks_coffee_mobile/screens/splash_screen.dart';
import 'package:ciks_coffee_mobile/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash adapts to small, large, and landscape screens', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(320, 568),
      const Size(430, 932),
      const Size(844, 390),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BrandMark), findsOneWidget);
      expect(find.text('Ciks Coffee'), findsOneWidget);
      expect(find.text('Rasa yang akrab.\nJeda yang berarti.'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Viewport $size');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('large text stays accessible without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ciks Coffee'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reduced motion shows the identity immediately with no animated loader',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const SplashScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FadeTransition>(
                find
                    .ancestor(
                      of: find.byType(BrandMark),
                      matching: find.byType(FadeTransition),
                    )
                    .first,
              )
              .opacity
              .value,
          1,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.bySemanticsLabel('Logo Ciks Coffee'), findsOneWidget);
        expect(find.bySemanticsLabel('Memuat Ciks Coffee'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
