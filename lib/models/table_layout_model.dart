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
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final double canvasWidth;
  final double canvasHeight;
  final Map<String, dynamic> backgroundConfig;
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
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class LayoutBackgroundElement {
  const LayoutBackgroundElement({
    required this.type,
    required this.label,
    required this.positionX,
    required this.positionY,
  });

  final String type;
  final String label;
  final double positionX;
  final double positionY;

  factory LayoutBackgroundElement.fromJson(Map<String, dynamic> json) {
    return LayoutBackgroundElement(
      type: _asString(json['type'], fallback: 'feature'),
      label: _asString(json['label']),
      positionX: _asDouble(json['position_x']),
      positionY: _asDouble(json['position_y']),
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

  bool get isAvailable => status == 'available';

  factory CoffeeTableModel.fromJson(Map<String, dynamic> json) {
    final status = _asString(json['status'], fallback: 'unavailable');
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
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _asDateTime(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
