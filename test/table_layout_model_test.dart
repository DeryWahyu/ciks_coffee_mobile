import 'package:ciks_coffee_mobile/models/table_layout_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a customer table-layout payload safely', () {
    final data = TableLayoutData.fromJson({
      'layout': {
        'id': 1,
        'name': 'Area Utama',
        'canvas_width': '1200',
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
          'id': 10,
          'code': 'M01',
          'name': 'Meja 1',
          'capacity': '2',
          'shape': 'round',
          'position_x': 12,
          'position_y': 17,
          'width': 13,
          'height': 13,
          'rotation': 0,
          'status': 'available',
          'status_label': 'Tersedia',
        },
        {
          'id': 11,
          'code': 'M02',
          'name': 'Meja 2',
          'capacity': 4,
          'shape': 'square',
          'position_x': 40,
          'position_y': 17,
          'width': 13,
          'height': 13,
          'rotation': 0,
          'status': 'reserved',
        },
      ],
    });

    expect(data.layout.canvasWidth, 1200);
    expect(data.layout.backgroundElements.single.label, 'Kasir & Bar');
    expect(data.summary.available, 1);
    expect(data.tables.first.capacity, 2);
    expect(data.tables.last.statusLabel, 'Dipesan');
  });
}
