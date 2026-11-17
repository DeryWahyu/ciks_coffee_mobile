class TableLayoutData {
  const TableLayoutData({
    required this.layout,
    required this.summary,
    required this.tables,
  });

  final FloorLayoutModel layout;
  final TableAvailabilitySummary summary;
  final List<CoffeeTableModel> tables;

  factory TableLayoutData.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'];
    final tables = rawTables is List
        ? rawTables
              .whereType<Map>()
              .map(
                (item) =>
                    CoffeeTableModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <CoffeeTableModel>[];

    return TableLayoutData(
      layout: FloorLayoutModel.fromJson(_asMap(json['layout'])),
      summary: TableAvailabilitySummary.fromJson(_asMap(json['summary'])),
      tables: tables,
    );
  }
}

class FloorLayoutModel {
  const FloorLayoutModel({
    required this.id,
    required this.name,
    required this.description,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.backgroundConfig,
    this.backgroundImage,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final double canvasWidth;
  final double canvasHeight;
  final Map<String, dynamic> backgroundConfig;
  final FloorPlanBackground? backgroundImage;
  final DateTime? updatedAt;

  List<LayoutBackgroundElement> get backgroundElements {
    final rawElements = backgroundConfig['elements'];
    if (rawElements is! List) return const [];

    return rawElements
        .whereType<Map>()
        .map(
          (item) =>
              LayoutBackgroundElement.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  bool get showGrid => backgroundConfig['show_grid'] != false;

  factory FloorLayoutModel.fromJson(Map<String, dynamic> json) {
    final canvasWidth = _asDouble(json['canvas_width'], fallback: 1200);
    final canvasHeight = _asDouble(json['canvas_height'], fallback: 800);
    return FloorLayoutModel(
      id: _asInt(json['id']),
      name: _asString(json['name'], fallback: 'Denah meja'),
      description: _asNullableString(json['description']),
      canvasWidth: canvasWidth > 0 ? canvasWidth : 1200,
      canvasHeight: canvasHeight > 0 ? canvasHeight : 800,
      backgroundConfig: _asMap(json['background_config']),
      backgroundImage: FloorPlanBackground.fromJson(json['background_image']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class FloorPlanBackground {
  const FloorPlanBackground({
    required this.url,
    required this.width,
    required this.height,
    required this.alt,
  });

  final String url;
  final double width;
  final double height;
  final String alt;

  static FloorPlanBackground? fromJson(dynamic value) {
    final data = _asMap(value);
    final url = _asString(data['url']);
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        (uri.hasScheme && !['http', 'https'].contains(uri.scheme))) {
      return null;
    }
    return FloorPlanBackground(
      url: url,
      width: _asDouble(data['width'], fallback: 3508),
      height: _asDouble(data['height'], fallback: 2481),
      alt: _asString(data['alt'], fallback: 'Denah Ciks Coffee'),
    );
  }
}

class LayoutBackgroundElement {
  const LayoutBackgroundElement({
    required this.type,
    required this.label,
    required this.positionX,
    required this.positionY,
    this.width = 20,
    this.height = 16,
    this.rotation = 0,
    this.fill = 'none',
    this.fontSize = 12,
  });

  final String type;
  final String label;
  final double positionX;
  final double positionY;
  final double width;
  final double height;
  final double rotation;
  final String fill;
  final double fontSize;

  // The same defaults are used by the web floor-plan renderer.
  static const defaults = <String, (double, double, String)>{
    'rectangle': (20, 16, 'none'),
    'ellipse': (14, 20, 'none'),
    'line': (24, .5, 'none'),
    'wall': (28, 1, 'none'),
    'text': (22, 7, 'none'),
    'area': (40, 42, 'stone'),
    'parking': (35, 24, 'stone'),
    'counter': (18, 8, 'sand'),
    'entrance': (14, 6, 'none'),
    'window': (3, 20, 'none'),
    'toilet': (10, 12, 'stone'),
    'plant': (5, 7, 'sage'),
    'stairs': (12, 16, 'none'),
  };

  factory LayoutBackgroundElement.fromJson(Map<String, dynamic> json) {
    final rawType = _asString(json['type'], fallback: 'rectangle');
    final type = defaults.containsKey(rawType) ? rawType : 'rectangle';
    final size = defaults[type]!;
    final fill = _asString(json['fill'], fallback: size.$3);
    return LayoutBackgroundElement(
      type: type,
      label: _asString(json['label']),
      positionX: _asDouble(json['position_x'], fallback: 50).clamp(0, 100),
      positionY: _asDouble(json['position_y'], fallback: 50).clamp(0, 100),
      width: _asDouble(json['width'], fallback: size.$1).clamp(.5, 100),
      height: _asDouble(json['height'], fallback: size.$2).clamp(.5, 100),
      rotation: _asDouble(json['rotation']) % 360,
      fill:
          [
            'none',
            'latte',
            'cream',
            'espresso',
            'stone',
            'sand',
            'sage',
          ].contains(fill)
          ? fill
          : 'none',
      fontSize: _asDouble(json['font_size'], fallback: 12).clamp(8, 32),
    );
  }
}

class CoffeeTableModel {
  const CoffeeTableModel({
    required this.id,
    required this.code,
    required this.name,
    required this.capacity,
    required this.shape,
    required this.positionX,
    required this.positionY,
    required this.width,
    required this.height,
    required this.rotation,
    required this.status,
    required this.statusLabel,
    this.statusUpdatedAt,
    this.chairPositions,
  });

  final int id;
  final String code;
  final String name;
  final int capacity;
  final String shape;
  final double positionX;
  final double positionY;
  final double width;
  final double height;
  final double rotation;
  final String status;
  final String statusLabel;
  final DateTime? statusUpdatedAt;
  final List<String>? chairPositions;

  bool get isAvailable => status == 'available';

  factory CoffeeTableModel.fromJson(Map<String, dynamic> json) {
    final status = _asString(json['status'], fallback: 'unavailable');
    final positions = json['chair_positions'];
    final validPositions =
        positions is List &&
        positions.length == _asInt(json['capacity']) &&
        positions.every(
          (side) => ['left', 'right', 'front', 'back'].contains(side),
        );
    return CoffeeTableModel(
      id: _asInt(json['id']),
      code: _asString(json['code'], fallback: 'MEJA'),
      name: _asString(json['name'], fallback: 'Meja'),
      capacity: _asInt(json['capacity'], fallback: 0),
      shape: _asString(json['shape'], fallback: 'round'),
      positionX: _asDouble(json['position_x']),
      positionY: _asDouble(json['position_y']),
      width: _asDouble(json['width'], fallback: 12),
      height: _asDouble(json['height'], fallback: 12),
      rotation: _asDouble(json['rotation']),
      status: status,
      chairPositions: validPositions
          ? List<String>.unmodifiable(positions)
          : null,
      statusLabel: _asString(
        json['status_label'],
        fallback: tableStatusLabel(status),
      ),
      statusUpdatedAt: _asDateTime(json['status_updated_at']),
    );
  }
}

class TableAvailabilitySummary {
  const TableAvailabilitySummary({
    required this.total,
    required this.available,
    required this.occupied,
    required this.reserved,
    required this.unavailable,
  });

  final int total;
  final int available;
  final int occupied;
  final int reserved;
  final int unavailable;

  factory TableAvailabilitySummary.fromJson(Map<String, dynamic> json) {
    return TableAvailabilitySummary(
      total: _asInt(json['total']),
      available: _asInt(json['available']),
      occupied: _asInt(json['occupied']),
      reserved: _asInt(json['reserved']),
      unavailable: _asInt(json['unavailable']),
    );
  }
}

String tableStatusLabel(String status) {
  switch (status) {
    case 'available':
      return 'Tersedia';
    case 'occupied':
      return 'Terisi';
    case 'reserved':
      return 'Dipesan';
    case 'unavailable':
      return 'Tidak tersedia';
    default:
      return 'Tidak diketahui';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _asString(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String? _asNullableString(dynamic value) {
  final result = _asString(value);
  return result.isEmpty ? null : result;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : fallback;
}

DateTime? _asDateTime(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
