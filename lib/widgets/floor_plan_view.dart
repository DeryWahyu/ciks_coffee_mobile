import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/table_layout_model.dart';

class FloorPlanPalette {
  static const ink = Color(0xFF3E2723);
  static const outline = Color(0xFF5D4037);
  static const muted = Color(0xFF8D6E63);
  static const line = Color(0xFFD7CCC8);
  static const cream = Color(0xFFFAFAF0);

  static Color status(String status) => switch (status) {
    'available' => const Color(0xFF16856F),
    'occupied' => const Color(0xFFD9634D),
    'reserved' => const Color(0xFFBD7A24),
    _ => const Color(0xFF7A818C),
  };
}

class FloorPlanSeat {
  const FloorPlanSeat(this.bounds, {this.round = false, this.sofa = false});
  final Rect bounds;
  final bool round;
  final bool sofa;
}

/// Relative chair geometry mirrors CiksFloorPlan.appendSeating on the web.
List<FloorPlanSeat> floorPlanSeats(
  CoffeeTableModel table,
  Map<String, dynamic> config,
) {
  final positions = table.chairPositions;
  if (positions != null &&
      positions.length == table.capacity &&
      positions.isNotEmpty &&
      positions.every(
        (side) => ['left', 'right', 'front', 'back'].contains(side),
      )) {
    final used = <String, int>{'left': 0, 'right': 0, 'front': 0, 'back': 0};
    return positions
        .map((side) {
          final count = positions.where((value) => value == side).length;
          final slot = used[side]!;
          used[side] = slot + 1;
          if (table.shape == 'round') {
            final size = math.min(.30, .70 / count);
            final centerAngle = <String, double>{
              'right': 0,
              'front': math.pi / 2,
              'left': math.pi,
              'back': -math.pi / 2,
            }[side]!;
            final angle =
                centerAngle + ((slot + .5) / count - .5) * math.pi / 2;
            final radius = .54 + size / 2;
            return FloorPlanSeat(
              Rect.fromLTWH(
                .5 + math.cos(angle) * radius - size / 2,
                .5 + math.sin(angle) * radius - size / 2,
                size,
                size,
              ),
              round: true,
            );
          }
          final size = math.min(.30, .80 / count),
              center = .10 + (slot + .5) * .80 / count;
          return FloorPlanSeat(
            side == 'left' || side == 'right'
                ? Rect.fromLTWH(
                    side == 'left' ? -.18 : 1.10,
                    center - size / 2,
                    .08,
                    size,
                  )
                : Rect.fromLTWH(
                    center - size / 2,
                    side == 'back' ? -.18 : 1.10,
                    size,
                    .08,
                  ),
          );
        })
        .toList(growable: false);
  }
  final seating = config['table_seating'];
  final preferred = seating is Map
      ? seating['id:${table.id}'] ?? seating[table.code]
      : null;
  final style =
      preferred ??
      (table.shape == 'round' && table.capacity == 2
          ? 'round_pair'
          : 'standard');
  if (style == 'sofa_pair') {
    return const [
      FloorPlanSeat(Rect.fromLTWH(-1.04, -.06, .86, 1.11), sofa: true),
      FloorPlanSeat(Rect.fromLTWH(1.20, -.06, .86, 1.11), sofa: true),
    ];
  }
  if (style == 'bench') {
    return const [FloorPlanSeat(Rect.fromLTWH(.16, 1.25, .41, .23))];
  }
  if (style == 'round_pair') {
    return const [
      FloorPlanSeat(Rect.fromLTWH(-.74, .23, .53, .53), round: true),
      FloorPlanSeat(Rect.fromLTWH(1.21, .23, .53, .53), round: true),
    ];
  }
  final count = table.capacity.clamp(1, 20);
  if (table.shape == 'round') {
    return List.generate(count, (index) {
      final angle = math.pi * 2 * index / count;
      return FloorPlanSeat(
        Rect.fromLTWH(
          .35 + math.cos(angle) * .8,
          .35 + math.sin(angle) * .8,
          .3,
          .3,
        ),
        round: true,
      );
    });
  }
  final top = (count / 2).ceil(), bottom = (count / 2).floor();
  return [
    for (var i = 0; i < top; i++)
      FloorPlanSeat(Rect.fromLTWH((i + .5) / top - .15, -.18, .3, .08)),
    for (var i = 0; i < bottom; i++)
      FloorPlanSeat(Rect.fromLTWH((i + .5) / bottom - .15, 1.11, .3, .08)),
  ];
}

/// Read-only canvas. All coordinates and dimensions come from the same API as the web.
class FloorPlanView extends StatelessWidget {
  const FloorPlanView({
    super.key,
    required this.data,
    required this.onTableTap,
    this.backgroundUrl,
    this.backgroundImageProvider,
    this.english = false,
  });

  final TableLayoutData data;
  final ValueChanged<CoffeeTableModel> onTableTap;
  final String? backgroundUrl;
  final ImageProvider? backgroundImageProvider;
  final bool english;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final background = data.layout.backgroundImage;
      return ColoredBox(
        key: const ValueKey('floor-plan-canvas'),
        color: Colors.white,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (background != null &&
                (backgroundImageProvider != null || backgroundUrl != null))
              Positioned.fill(
                child: IgnorePointer(
                  child: Image(
                    key: const ValueKey('floor-plan-background'),
                    image:
                        backgroundImageProvider ?? NetworkImage(backgroundUrl!),
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    semanticLabel: background.alt,
                    errorBuilder: (_, error, stack) => Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          english
                              ? 'Background could not load. Table positions are still shown.'
                              : 'Latar belum termuat. Posisi meja tetap ditampilkan.',
                          style: const TextStyle(
                            fontFamily: 'CiksSans',
                            fontSize: 9,
                            color: FloorPlanPalette.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (data.layout.showGrid)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _PlanGridPainter()),
                ),
              ),
            for (var i = 0; i < data.layout.backgroundElements.length; i++)
              _element(data.layout.backgroundElements[i], size, i),
            for (final table in data.tables) _table(table, size),
          ],
        ),
      );
    },
  );

  Widget _element(LayoutBackgroundElement element, Size size, int index) {
    final width = size.width * element.width / 100,
        height = size.height * element.height / 100;
    final textOnly = element.type == 'text';
    final line = element.type == 'line' || element.type == 'wall';
    final solid =
        [
          'counter',
          'entrance',
          'window',
          'toilet',
          'stairs',
        ].contains(element.type) ||
        line;
    final background = solid
        ? Colors.white
        : switch (element.fill) {
            'latte' => const Color(0xFFE8E0DD),
            'espresso' => FloorPlanPalette.ink,
            'cream' || 'stone' || 'sand' || 'sage' => FloorPlanPalette.cream,
            _ => Colors.transparent,
          };
    final fill = textOnly ? Colors.transparent : background;
    final color = element.fill == 'espresso' && !solid && !textOnly
        ? const Color(0xFFF5F5DC)
        : FloorPlanPalette.ink;
    final font = math.min(
      element.fontSize,
      math.max(7.0, size.width * element.fontSize / 700),
    );
    final upper = element.type == 'area' || element.type == 'parking';
    final label = Text(
      upper ? element.label.toUpperCase() : element.label,
      textAlign: upper ? TextAlign.left : TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'CiksSans',
        fontSize: upper ? font * .83 : font,
        height: 1.2,
        fontWeight: upper ? FontWeight.w700 : FontWeight.w400,
        color: color,
      ),
    );
    return Positioned(
      left: size.width * element.positionX / 100,
      top: size.height * element.positionY / 100,
      width: width,
      height: height,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: Transform.rotate(
          angle: element.rotation * math.pi / 180,
          child: IgnorePointer(
            child: Container(
              key: ValueKey('floor-element-$index'),
              decoration: BoxDecoration(
                color: fill,
                border: textOnly
                    ? null
                    : Border.all(color: FloorPlanPalette.outline, width: .8),
                borderRadius: BorderRadius.circular(
                  ['ellipse', 'plant'].contains(element.type) ? 999 : 0,
                ),
              ),
              child: CustomPaint(
                painter: element.type == 'stairs'
                    ? const _StairsPainter()
                    : null,
                child: line
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (element.label.isNotEmpty)
                            Positioned(
                              bottom: height,
                              left: 0,
                              child: ColoredBox(
                                color: Colors.white,
                                child: label,
                              ),
                            ),
                        ],
                      )
                    : Padding(
                        padding: EdgeInsets.all(
                          upper ? math.min(8, width / 10) : 0,
                        ),
                        child: Align(
                          alignment: upper
                              ? Alignment.topLeft
                              : Alignment.center,
                          child: label,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(CoffeeTableModel table, Size size) {
    final width = size.width * table.width / 100,
        height = size.height * table.height / 100;
    final round = table.shape == 'round';
    final radius = BorderRadius.circular(round ? 999 : 1);
    final seats = floorPlanSeats(table, data.layout.backgroundConfig);
    final statusDot = ExcludeSemantics(
      child: Container(
        key: ValueKey('table-status-dot-${table.id}'),
        width: (size.width * .0065).clamp(5, 8),
        height: (size.width * .0065).clamp(5, 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FloorPlanPalette.status(table.status),
        ),
      ),
    );
    return Positioned(
      left: size.width * table.positionX / 100,
      top: size.height * table.positionY / 100,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: table.rotation * math.pi / 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < seats.length; i++)
              Positioned(
                left: width * seats[i].bounds.left,
                top: height * seats[i].bounds.top,
                width: width * seats[i].bounds.width,
                height: height * seats[i].bounds.height,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    key: ValueKey('table-seat-${table.id}-$i'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: FloorPlanPalette.outline,
                        width: .8,
                      ),
                      borderRadius: BorderRadius.circular(
                        seats[i].round ? 999 : 0,
                      ),
                    ),
                    child: seats[i].sofa
                        ? Center(
                            child: Text(
                              'sofa',
                              style: TextStyle(
                                fontFamily: 'CiksSans',
                                color: FloorPlanPalette.ink,
                                fontSize: (size.width * .01).clamp(6, 12),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            Positioned.fill(
              child: Semantics(
                key: ValueKey('table-marker-${table.id}'),
                button: true,
                excludeSemantics: true,
                onTap: () => onTableTap(table),
                label:
                    '${table.code}, ${table.name}, ${table.capacity} ${english ? 'seats' : 'kursi'}, ${_statusLabel(table.status)}',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTableTap(table),
                    borderRadius: radius,
                    child: Ink(
                      key: ValueKey('table-body-${table.id}'),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: FloorPlanPalette.outline,
                          width: .8,
                        ),
                        borderRadius: radius,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (round) ...[
                                      statusDot,
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      table.code,
                                      style: TextStyle(
                                        fontFamily: 'CiksSans',
                                        fontSize: (size.width * .01).clamp(
                                          7,
                                          12,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        color: FloorPlanPalette.ink,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${table.capacity} ${english ? 'seats' : 'kursi'}',
                                      style: TextStyle(
                                        fontFamily: 'CiksSans',
                                        fontSize: (size.width * .007).clamp(
                                          5,
                                          9,
                                        ),
                                        color: FloorPlanPalette.muted,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!round)
                            Positioned(top: 3, right: 3, child: statusDot),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => english
      ? switch (status) {
          'available' => 'Available',
          'occupied' => 'Occupied',
          'reserved' => 'Reserved',
          _ => 'Unavailable',
        }
      : tableStatusLabel(status);
}

class _PlanGridPainter extends CustomPainter {
  const _PlanGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = FloorPlanPalette.line;
    for (var x = 0.0; x < size.width; x += 20) {
      for (var y = 0.0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), .7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlanGridPainter oldDelegate) => false;
}

class _StairsPainter extends CustomPainter {
  const _StairsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FloorPlanPalette.line
      ..strokeWidth = 1;
    for (var y = 9.0; y < size.height; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StairsPainter oldDelegate) => false;
}
