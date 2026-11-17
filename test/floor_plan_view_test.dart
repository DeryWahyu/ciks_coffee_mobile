import 'dart:convert';
import 'dart:typed_data';

import 'package:ciks_coffee_mobile/models/table_layout_model.dart';
import 'package:ciks_coffee_mobile/widgets/floor_plan_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _pixel = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGP8//8/AwwwwVl4OQCWbgMF7ZjH1AAAAABJRU5ErkJggg==',
  ),
);

void main() {
  test(
    'custom chairs follow all four edges and fit crowded edges on web geometry',
    () {
      final table = CoffeeTableModel.fromJson({
        ..._tableJson(1, 'available'),
        'chair_positions': ['left', 'right', 'front', 'back'],
      });
      final seats = floorPlanSeats(table, {
        'table_seating': {'id:1': 'sofa_pair'},
      });
      expect(seats.length, 4);
      expect(seats[0].bounds, const Rect.fromLTWH(-.18, .35, .08, .30));
      expect(seats[1].bounds.left, 1.10);
      expect(seats[2].bounds.top, 1.10);
      expect(seats[3].bounds.top, -.18);
      final crowded = CoffeeTableModel.fromJson({
        ..._tableJson(1, 'available'),
        'capacity': 20,
        'chair_positions': List.filled(20, 'left'),
      });
      final packed = floorPlanSeats(crowded, {});
      expect(packed.length, 20);
      for (var i = 0; i < packed.length; i++) {
        expect(packed[i].bounds.top, greaterThanOrEqualTo(0));
        expect(packed[i].bounds.bottom, lessThanOrEqualTo(1));
        if (i > 0) {
          expect(
            packed[i - 1].bounds.bottom,
            lessThanOrEqualTo(packed[i].bounds.top + 1e-9),
          );
        }
      }
      final round = CoffeeTableModel.fromJson({
        ..._tableJson(1, 'available'),
        'shape': 'round',
        'chair_positions': ['left', 'right', 'front', 'back'],
      });
      final roundSeats = floorPlanSeats(round, {});
      expect(roundSeats.every((seat) => seat.round), isTrue);
      expect(roundSeats[0].bounds.right, closeTo(-.04, 1e-9));
      expect(roundSeats[2].bounds.top, closeTo(1.04, 1e-9));
      final malformed = CoffeeTableModel.fromJson({
        ..._tableJson(1, 'available'),
        'chair_positions': ['outside'],
      });
      expect(malformed.chairPositions, isNull);
    },
  );

  test(
    'standard chairs, round pairs, benches and sofas use the web geometry',
    () {
      final square = _table(1, 'available');
      final normal = floorPlanSeats(square, {});
      expect(normal.length, 4);
      expect(normal.first.bounds, const Rect.fromLTWH(.1, -.18, .3, .08));
      expect(normal.last.bounds.top, 1.11);
      final round = CoffeeTableModel.fromJson({
        ..._tableJson(1, 'available'),
        'shape': 'round',
        'capacity': 2,
      });
      final pair = floorPlanSeats(round, {});
      expect(pair.length, 2);
      expect(pair.first.round, isTrue);
      expect(pair.first.bounds, const Rect.fromLTWH(-.74, .23, .53, .53));
      final sofas = floorPlanSeats(square, {
        'table_seating': {'id:1': 'sofa_pair', 'M1': 'bench'},
      });
      expect(sofas.length, 2);
      expect(sofas.every((seat) => seat.sofa), isTrue);
      expect(sofas.last.bounds, const Rect.fromLTWH(1.2, -.06, .86, 1.11));
      expect(
        floorPlanSeats(square, {
          'table_seating': {'M1': 'bench'},
        }).single.bounds,
        const Rect.fromLTWH(.16, 1.25, .41, .23),
      );
    },
  );

  testWidgets(
    'all statuses retain white table bodies and only dots change color',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      CoffeeTableModel? tapped;
      final data = _fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 700,
                height: 500,
                child: FloorPlanView(
                  data: data,
                  onTableTap: (table) => tapped = table,
                ),
              ),
            ),
          ),
        ),
      );
      for (final table in data.tables) {
        final body = tester.widget<Ink>(
          find.byKey(ValueKey('table-body-${table.id}')),
        );
        final decoration = body.decoration! as BoxDecoration;
        expect(decoration.color, Colors.white);
        expect(decoration.gradient, isNull);
        final dot = tester.widget<Container>(
          find.byKey(ValueKey('table-status-dot-${table.id}')),
        );
        expect(
          (dot.decoration! as BoxDecoration).color,
          FloorPlanPalette.status(table.status),
        );
        final marker = tester.widget<Semantics>(
          find.byKey(ValueKey('table-marker-${table.id}')),
        );
        expect(marker.properties.label, contains(table.statusLabel));
      }
      final canvas = tester.getRect(
        find.byKey(const ValueKey('floor-plan-canvas')),
      );
      final table = tester.getRect(
        find.byKey(const ValueKey('table-marker-1')),
      );
      expect(table.left - canvas.left, closeTo(70, .01));
      expect(table.top - canvas.top, closeTo(150, .01));
      expect(table.width, closeTo(70, .01));
      expect(table.height, closeTo(50, .01));
      await tester.tap(find.byKey(const ValueKey('table-marker-1')));
      expect(tapped?.id, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uses the supplied raster with contain and keeps editor rotation and size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = _fixture(
        background: true,
        elements: [
          {
            'type': 'rectangle',
            'label': 'Indoor',
            'position_x': 50,
            'position_y': 20,
            'width': 20,
            'height': 10,
            'rotation': 90,
            'fill': 'latte',
          },
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 700,
                height: 500,
                child: FloorPlanView(
                  data: data,
                  backgroundImageProvider: MemoryImage(_pixel),
                  onTableTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Image>(find.byKey(const ValueKey('floor-plan-background')))
            .fit,
        BoxFit.contain,
      );
      final element = tester.getRect(
        find.byKey(const ValueKey('floor-element-0')),
      );
      expect(element.width, closeTo(50, .01));
      expect(element.height, closeTo(140, .01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed background leaves the table layout usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 500,
            child: FloorPlanView(
              data: _fixture(background: true),
              backgroundImageProvider: MemoryImage(
                Uint8List.fromList([1, 2, 3]),
              ),
              onTableTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Latar belum termuat. Posisi meja tetap ditampilkan.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('table-marker-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _tableJson(int id, String status) => {
  'id': id,
  'code': 'M$id',
  'name': 'Meja $id',
  'capacity': 4,
  'shape': 'square',
  'position_x': 10 + (id - 1) * 20,
  'position_y': 30,
  'width': 10,
  'height': 10,
  'rotation': 0,
  'status': status,
  'status_label': tableStatusLabel(status),
};
CoffeeTableModel _table(int id, String status) =>
    CoffeeTableModel.fromJson(_tableJson(id, status));
TableLayoutData _fixture({
  bool background = false,
  List<Map<String, dynamic>> elements = const [],
}) => TableLayoutData.fromJson({
  'layout': {
    'id': 1,
    'name': 'Area Utama',
    'canvas_width': 1400,
    'canvas_height': 1000,
    if (background)
      'background_image': {
        'url': 'https://test.invalid/floor.png',
        'width': 3508,
        'height': 2481,
      },
    'background_config': {'show_grid': false, 'elements': elements},
  },
  'summary': {
    'total': 4,
    'available': 1,
    'occupied': 1,
    'reserved': 1,
    'unavailable': 1,
  },
  'tables': [
    for (final entry in [
      'available',
      'occupied',
      'reserved',
      'unavailable',
    ].asMap().entries)
      _tableJson(entry.key + 1, entry.value),
  ],
});
