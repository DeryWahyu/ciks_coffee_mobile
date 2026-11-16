import 'package:ciks_coffee_mobile/models/table_layout_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains the web background and full editor geometry', () {
    final layout = FloorLayoutModel.fromJson({
      'id': 1,
      'name': 'Kedai',
      'canvas_width': 3508,
      'canvas_height': 2481,
      'background_image': {
        'url':
            'https://cikscoffee.biz.id/images/floor-plans/cikscoffee-floor-plan.png',
        'width': 3508,
        'height': 2481,
        'alt': 'Denah kedai',
      },
      'background_config': {
        'show_grid': false,
        'table_seating': {'id:10': 'sofa_pair'},
        'elements': [
          {
            'type': 'rectangle',
            'label': 'Outdoor',
            'position_x': 12.5,
            'position_y': 30,
            'width': 28,
            'height': 14,
            'rotation': 90,
            'fill': 'latte',
            'font_size': 20,
          },
        ],
      },
    });
    expect(layout.backgroundImage?.width, 3508);
    expect(layout.backgroundImage?.height, 2481);
    expect(layout.backgroundImage?.alt, 'Denah kedai');
    expect(layout.showGrid, isFalse);
    final element = layout.backgroundElements.single;
    expect(element.width, 28);
    expect(element.height, 14);
    expect(element.rotation, 90);
    expect(element.fill, 'latte');
    expect(element.fontSize, 20);
    expect(layout.backgroundConfig['table_seating'], {'id:10': 'sofa_pair'});
  });

  test('legacy elements use the same dimensions and fills as the web', () {
    final counter = LayoutBackgroundElement.fromJson({
      'type': 'counter',
      'label': 'Kasir',
    });
    expect(counter.width, 18);
    expect(counter.height, 8);
    expect(counter.fill, 'sand');
    expect(counter.positionX, 50);
    final line = LayoutBackgroundElement.fromJson({'type': 'line'});
    expect(line.height, .5);
    expect(FloorLayoutModel.fromJson({}).backgroundImage, isNull);
  });

  test(
    'invalid image schemes and non-finite layout dimensions are not rendered',
    () {
      final layout = FloorLayoutModel.fromJson({
        'canvas_width': 'NaN',
        'canvas_height': -5,
        'background_image': {'url': 'javascript:alert(1)'},
      });
      expect(layout.canvasWidth, 1200);
      expect(layout.canvasHeight, 800);
      expect(layout.backgroundImage, isNull);
      final element = LayoutBackgroundElement.fromJson({
        'type': 'unknown',
        'width': 'Infinity',
        'fill': 'unknown',
      });
      expect(element.type, 'rectangle');
      expect(element.width, 20);
      expect(element.fill, 'none');
    },
  );

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
