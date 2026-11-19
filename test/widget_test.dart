import 'package:flutter_test/flutter_test.dart';

import 'package:ciks_coffee_mobile/main.dart';
import 'package:ciks_coffee_mobile/screens/splash_screen.dart';
import 'package:ciks_coffee_mobile/widgets/brand_mark.dart';

void main() {
  testWidgets('app starts with its material shell and CIKS splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(BrandWordmark), findsOneWidget);
  });
}
