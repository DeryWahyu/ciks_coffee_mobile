import 'package:flutter_test/flutter_test.dart';

import 'package:ciks_coffee_mobile/main.dart';

void main() {
  testWidgets('app starts with its material shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.text('Ciks Coffee'), findsOneWidget);
  });
}
