import 'package:ciks_coffee_mobile/models/table_layout_model.dart';
import 'package:ciks_coffee_mobile/screens/table_availability_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the visual layout, legend, and accessible table detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Area Utama'), findsOneWidget);
    expect(find.text('Keterangan status'), findsOneWidget);
    expect(find.text('Tersedia'), findsAtLeastNWidgets(1));
    expect(find.text('Terisi'), findsOneWidget);
    expect(find.text('Dipesan'), findsOneWidget);
    expect(find.text('Tidak tersedia'), findsOneWidget);
    final firstTable = find.byKey(const ValueKey('table-marker-1'));
    expect(firstTable, findsOneWidget);
    expect(
      tester.widget<Semantics>(firstTable).properties.label,
      'M01, Meja 1, 2 kursi, Tersedia',
    );

    await tester.tap(firstTable);
    await tester.pumpAndSettle();

    expect(find.text('Meja 1'), findsAtLeastNWidgets(1));
    expect(find.text('Kode M01'), findsOneWidget);
    expect(find.text('2 kursi'), findsOneWidget);
  });

  testWidgets('keeps the floor layout free from overflow on a wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Denah ketersediaan'), findsOneWidget);
    expect(find.byKey(const ValueKey('table-marker-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('polls only while the screen is active', (tester) async {
    final apiService = _FakeTableApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: TableAvailabilityScreen(
          apiService: apiService,
          pollingInterval: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(apiService.requestCount, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(apiService.requestCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(apiService.requestCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(apiService.requestCount, 3);
  });
}

Widget _testApp() {
  return MaterialApp(
    home: TableAvailabilityScreen(
      apiService: _FakeTableApiService(),
      pollingInterval: const Duration(days: 1),
    ),
  );
}

class _FakeTableApiService extends ApiService {
  int requestCount = 0;

  @override
  Future<Map<String, dynamic>> getTableLayout() async {
    requestCount++;
    return {
      'success': true,
      'data': TableLayoutData.fromJson({
        'layout': {
          'id': 1,
          'name': 'Area Utama',
          'canvas_width': 1200,
          'canvas_height': 800,
          'background_config': {
            'show_grid': true,
            'elements': [
              {
                'type': 'counter',
                'label': 'Kasir & Bar',
                'position_x': 50,
                'position_y': 5,
              },
            ],
          },
        },
        'summary': {
          'total': 2,
          'available': 1,
          'occupied': 1,
          'reserved': 0,
          'unavailable': 0,
        },
        'tables': [
          {
            'id': 1,
            'code': 'M01',
            'name': 'Meja 1',
            'capacity': 2,
            'shape': 'round',
            'position_x': 12,
            'position_y': 20,
            'width': 16,
            'height': 20,
            'rotation': 0,
            'status': 'available',
            'status_label': 'Tersedia',
          },
          {
            'id': 2,
            'code': 'M02',
            'name': 'Meja 2',
            'capacity': 4,
            'shape': 'square',
            'position_x': 58,
            'position_y': 42,
            'width': 19,
            'height': 20,
            'rotation': 0,
            'status': 'occupied',
            'status_label': 'Terisi',
          },
        ],
      }),
    };
  }
}
