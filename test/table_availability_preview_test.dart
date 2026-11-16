import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ciks_coffee_mobile/models/table_layout_model.dart';
import 'package:ciks_coffee_mobile/screens/table_availability_screen.dart';
import 'package:ciks_coffee_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'complete customer plan stays read-only and can be viewed at phone and landscape sizes',
    (tester) async {
      final output = Platform.environment['CIKS_FLOOR_QA_DIR'];
      final background = Platform.environment['CIKS_FLOOR_QA_BACKGROUND'];
      final pixel = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGP8//8/AwwwwVl4OQCWbgMF7ZjH1AAAAABJRU5ErkJggg==',
        ),
      );
      final ImageProvider provider = background == null
          ? MemoryImage(pixel)
          : MemoryImage(File(background).readAsBytesSync());
      if (output != null) {
        await tester.runAsync(() async {
          final font = FontLoader('CiksSans')
            ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        final boundary = GlobalKey();
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: 'CiksSans',
                colorSchemeSeed: const Color(0xFF3E2723),
              ),
              home: TableAvailabilityScreen(
                apiService: _PreviewApi(),
                backgroundImageProvider: provider,
                pollingInterval: const Duration(days: 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rawImage = find.descendant(
          of: find.byKey(const ValueKey('floor-plan-background')),
          matching: find.byType(RawImage),
        );
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (rawImage.evaluate().isNotEmpty &&
              tester.widget<RawImage>(rawImage).image != null) {
            break;
          }
        }
        expect(tester.widget<RawImage>(rawImage).image, isNotNull);
        expect(
          find.byKey(const ValueKey('floor-plan-background')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('table-marker-1')), findsOneWidget);
        expect(find.text('Edit denah'), findsNothing);
        expect(find.text('Simpan denah'), findsNothing);
        expect(find.textContaining('Denah dummy'), findsNothing);
        if (output != null) {
          await _capture(
            tester,
            boundary,
            '$output/mobile-floor-${size.width.toInt()}.png',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

class _PreviewApi extends ApiService {
  @override
  Future<Map<String, dynamic>> getTableLayout() async => {
    'success': true,
    'data': TableLayoutData.fromJson({
      'layout': {
        'id': 1,
        'name': 'Area Utama',
        'canvas_width': 3508,
        'canvas_height': 2481,
        'description': 'Denah dummy Ciks Coffee.',
        'background_image': {
          'url': 'https://example.test/floor.png',
          'width': 3508,
          'height': 2481,
          'alt': 'Denah Ciks Coffee',
        },
        'background_config': {
          'show_grid': false,
          'elements': [],
          'table_seating': {'M03': 'sofa_pair'},
        },
      },
      'summary': {
        'total': 4,
        'available': 1,
        'occupied': 1,
        'reserved': 1,
        'unavailable': 1,
      },
      'tables': [
        {
          'id': 1,
          'code': 'M01',
          'name': 'Meja 1',
          'capacity': 4,
          'shape': 'square',
          'position_x': 8,
          'position_y': 32,
          'width': 10,
          'height': 10,
          'status': 'available',
        },
        {
          'id': 2,
          'code': 'M02',
          'name': 'Meja 2',
          'capacity': 2,
          'shape': 'round',
          'position_x': 30,
          'position_y': 32,
          'width': 7,
          'height': 10,
          'status': 'occupied',
        },
        {
          'id': 3,
          'code': 'M03',
          'name': 'Meja sofa',
          'capacity': 4,
          'shape': 'rectangle',
          'position_x': 22,
          'position_y': 58,
          'width': 7,
          'height': 12,
          'status': 'reserved',
        },
        {
          'id': 4,
          'code': 'M04',
          'name': 'Meja outdoor',
          'capacity': 4,
          'shape': 'rectangle',
          'position_x': 76,
          'position_y': 35,
          'width': 9,
          'height': 8,
          'rotation': 90,
          'status': 'unavailable',
        },
      ],
    }),
  };
}
