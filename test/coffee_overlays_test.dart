import 'package:ciks_coffee_mobile/widgets/coffee_overlays.dart';
import 'package:ciks_coffee_mobile/widgets/order_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'pickup needs an explicit choice and cancel never confirms pickup',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) =>
                        const PickupConfirmationDialog(orderNumber: 'CK-1234'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Konfirmasi hanya setelah'), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.byKey(const ValueKey('cancel-pickup')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-pickup')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );

  testWidgets(
    'sheet keeps its action above the keyboard while long content scrolls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: const EdgeInsets.only(bottom: 240)),
              child: Scaffold(
                body: CoffeeSheet(
                  title: 'Detail Pesanan',
                  footer: CoffeeButton(
                    key: const ValueKey('sheet-action'),
                    label: 'Selesai',
                    onPressed: () {},
                  ),
                  child: Column(
                    children: List.generate(
                      40,
                      (i) => Text('Baris pesanan $i'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('sheet-action'))).bottom,
        lessThanOrEqualTo(400),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation remains readable with large text on a small display',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: PickupConfirmationDialog(orderNumber: 'CK-20261024-0001'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('confirm-pickup')));
      expect(tester.takeException(), isNull);
    },
  );
}
