import 'package:ciks_coffee_mobile/models/table_layout_model.dart';
import 'package:ciks_coffee_mobile/screens/table_availability_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:ciks_coffee_mobile/widgets/coffee_overlays.dart';
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
    expect(
      find.descendant(
        of: find.byType(CoffeeSheet),
        matching: find.text('2 kursi'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the floor layout free from overflow on a wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Denah kedai'), findsOneWidget);
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

  testWidgets(
    'retains zoom while live positions and open table details update',
    (tester) async {
      final api = _FakeTableApiService();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: TableAvailabilityScreen(
            apiService: api,
            pollingInterval: const Duration(seconds: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final zoom = find.byKey(const ValueKey('floor-zoom-in'));
      await tester.ensureVisible(zoom);
      await tester.tap(zoom);
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const ValueKey('floor-plan-viewer')),
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(1.25, .001),
      );
      api.firstStatus = 'occupied';
      api.firstX = 30;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(1.25, .001),
      );
      final marker = find.byKey(const ValueKey('table-marker-1'));
      expect(
        tester.widget<Semantics>(marker).properties.label,
        contains('Terisi'),
      );
      await tester.ensureVisible(marker);
      await tester.tap(marker);
      await tester.pumpAndSettle();
      api.firstStatus = 'reserved';
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CoffeeSheet),
          matching: find.text('Dipesan'),
        ),
        findsOneWidget,
      );
      api.removeFirst = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Meja ini sudah tidak tersedia.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fits compact, landscape and wide screens with enlarged text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(900, 700),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.8)),
              child: TableAvailabilityScreen(
                apiService: _FakeTableApiService(),
                pollingInterval: const Duration(days: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('floor-zoom-in')));
      await tester.tap(find.byKey(const ValueKey('floor-zoom-in')));
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'removes dummy description and keeps the last usable map on connection failure',
    (tester) async {
      final api = _FakeTableApiService();
      await tester.pumpWidget(
        MaterialApp(
          home: TableAvailabilityScreen(
            apiService: api,
            pollingInterval: const Duration(seconds: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Denah dummy'), findsNothing);
      api.fail = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Koneksi uji terputus.'), findsOneWidget);
      expect(find.byKey(const ValueKey('table-marker-1')), findsOneWidget);
      api.fail = false;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Koneksi uji terputus.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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
  String firstStatus = 'available';
  double firstX = 12;
  bool fail = false;
  bool removeFirst = false;

  @override
  Future<Map<String, dynamic>> getTableLayout() async {
    requestCount++;
    if (fail) return {'success': false, 'message': 'Koneksi uji terputus.'};
    return {
      'success': true,
      'data': TableLayoutData.fromJson({
        'layout': {
          'id': 1,
          'name': 'Area Utama',
          'description':
              'Denah dummy Ciks Coffee. Posisi meja dapat diatur oleh pemilik pada editor layout.',
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
          'total': removeFirst ? 1 : 2,
          'available': !removeFirst && firstStatus == 'available' ? 1 : 0,
          'occupied': 1 + (!removeFirst && firstStatus == 'occupied' ? 1 : 0),
          'reserved': !removeFirst && firstStatus == 'reserved' ? 1 : 0,
          'unavailable': 0,
        },
        'tables': [
          if (!removeFirst)
            {
              'id': 1,
              'code': 'M01',
              'name': 'Meja 1',
              'capacity': 2,
              'shape': 'round',
              'position_x': firstX,
              'position_y': 20,
              'width': 16,
              'height': 20,
              'rotation': 0,
              'status': firstStatus,
              'status_label': tableStatusLabel(firstStatus),
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
