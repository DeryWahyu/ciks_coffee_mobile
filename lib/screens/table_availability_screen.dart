import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/table_layout_model.dart';
import '../services/api_service.dart';

class TableAvailabilityScreen extends StatefulWidget {
  const TableAvailabilityScreen({
    super.key,
    this.apiService,
    this.pollingInterval = const Duration(seconds: 15),
  });

  final ApiService? apiService;
  final Duration pollingInterval;

  @override
  State<TableAvailabilityScreen> createState() =>
      _TableAvailabilityScreenState();
}

class _TableAvailabilityScreenState extends State<TableAvailabilityScreen>
    with WidgetsBindingObserver {
  static const _espresso = Color(0xFF2C1810);
  static const _brown = Color(0xFF5D3A1A);
  static const _cream = Color(0xFFF8F1E8);

  late final ApiService _apiService;
  Timer? _pollingTimer;
  TableLayoutData? _data;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isRequestInFlight = false;
  DateTime? _lastRefreshedAt;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    WidgetsBinding.instance.addObserver(this);
    _loadLayout();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLayout(silent: _data != null);
      _startPolling();
      return;
    }

    _stopPolling();
  }

  void _startPolling() {
    if (_pollingTimer != null) return;
    _pollingTimer = Timer.periodic(widget.pollingInterval, (_) {
      _loadLayout(silent: true);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadLayout({bool silent = false}) async {
    if (_isRequestInFlight) return;
    _isRequestInFlight = true;

    if (mounted && !silent) {
      setState(() {
        _isLoading = _data == null;
        _isRefreshing = _data != null;
        _errorMessage = null;
      });
    }

    final result = await _apiService.getTableLayout();
    _isRequestInFlight = false;
    if (!mounted) return;

    if (result['success'] == true && result['data'] is TableLayoutData) {
      setState(() {
        _data = result['data'] as TableLayoutData;
        _errorMessage = null;
        _isLoading = false;
        _isRefreshing = false;
        _lastRefreshedAt = DateTime.now();
      });
      return;
    }

    setState(() {
      _errorMessage =
          result['message']?.toString() ?? 'Denah meja belum dapat dimuat.';
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        foregroundColor: _espresso,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Ketersediaan meja',
          style: GoogleFonts.poppins(
            color: _espresso,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isRefreshing ? null : () => _loadLayout(),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: data == null
          ? _buildInitialState()
          : RefreshIndicator(
              color: _brown,
              onRefresh: () => _loadLayout(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHero(data),
                        const SizedBox(height: 20),
                        _buildMapCard(data),
                        const SizedBox(height: 20),
                        _buildLegend(),
                        const SizedBox(height: 20),
                        _buildAvailabilityList(data),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInitialState() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _brown));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDE9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.table_restaurant_outlined,
                color: Color(0xFFD9634D),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Denah belum dapat dimuat',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _espresso,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _errorMessage ?? 'Silakan coba lagi dalam beberapa saat.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _espresso.withValues(alpha: 0.58),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadLayout,
              style: FilledButton.styleFrom(
                backgroundColor: _brown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(TableLayoutData data) {
    final summary = data.summary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D2517), Color(0xFF805434)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _brown.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -42,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_seat_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.layout.name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(color: Colors.white),
                  children: [
                    TextSpan(
                      text: '${summary.available} ',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: 'meja tersedia',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'dari ${summary.total} meja yang sedang ditampilkan',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 7,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FractionallySizedBox(
                  widthFactor: summary.total == 0
                      ? 0
                      : summary.available / summary.total,
                  alignment: Alignment.centerLeft,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF91DDC5)),
                  ),
                ),
              ),
              if (_lastRefreshedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Diperbarui ${DateFormat('HH:mm').format(_lastRefreshedAt!)} - otomatis setiap 15 detik',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(TableLayoutData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DCD2)),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Denah ketersediaan',
                        style: GoogleFonts.poppins(
                          color: _espresso,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ketuk meja untuk melihat detail status.',
                        style: GoogleFonts.poppins(
                          color: _espresso.withValues(alpha: 0.52),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EDE6),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.pinch_rounded,
                    color: Color(0xFF805434),
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final canvasHeight =
                    width *
                    (data.layout.canvasHeight / data.layout.canvasWidth);
                return InteractiveViewer(
                  minScale: 0.9,
                  maxScale: 3.2,
                  boundaryMargin: const EdgeInsets.all(36),
                  child: SizedBox(
                    width: width,
                    height: canvasHeight,
                    child: _buildFloorCanvas(data, width, canvasHeight),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCanvas(TableLayoutData data, double width, double height) {
    final children = <Widget>[
      CustomPaint(
        painter: data.layout.showGrid ? const _FloorGridPainter() : null,
        child: const ColoredBox(
          color: Color(0xFFFFFCF8),
          child: SizedBox.expand(),
        ),
      ),
    ];

    for (final element in data.layout.backgroundElements) {
      children.add(_buildBackgroundElement(element, width, height));
    }

    for (final table in data.tables) {
      children.add(_buildTableMarker(table, width, height));
    }

    return Stack(clipBehavior: Clip.hardEdge, children: children);
  }

  Widget _buildBackgroundElement(
    LayoutBackgroundElement element,
    double width,
    double height,
  ) {
    final style = _backgroundStyleFor(element.type);
    return Positioned(
      left: element.positionX / 100 * width,
      top: element.positionY / 100 * height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Container(
          constraints: BoxConstraints(
            minWidth: style.minWidth,
            minHeight: style.minHeight,
          ),
          padding: style.padding,
          decoration: BoxDecoration(
            color: style.background,
            border: Border.all(color: style.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            element.label,
            style: GoogleFonts.poppins(
              color: style.foreground,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableMarker(
    CoffeeTableModel table,
    double width,
    double height,
  ) {
    final statusStyle = _statusStyleFor(table.status);
    final tableWidth = table.width / 100 * width;
    final tableHeight = table.height / 100 * height;
    final smallestTableSide = math.min(tableWidth, tableHeight);
    final codeFontSize = math.max(3.5, math.min(9.0, smallestTableSide * 0.24));
    final nameFontSize = math.max(2.8, math.min(6.5, smallestTableSide * 0.16));
    final capacityFontSize = math.max(
      2.8,
      math.min(7.0, smallestTableSide * 0.17),
    );
    final iconSize = math.max(3.5, math.min(8.0, smallestTableSide * 0.18));
    final contentPadding = math.max(
      0.5,
      math.min(3.0, smallestTableSide * 0.08),
    );
    final chairSize = math.max(3.4, math.min(15.0, smallestTableSide * 0.38));

    return Positioned(
      left: table.positionX / 100 * width,
      top: table.positionY / 100 * height,
      width: tableWidth,
      height: tableHeight,
      child: Transform.rotate(
        angle: table.rotation * math.pi / 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ..._buildTableChairs(
              table.capacity,
              tableWidth,
              tableHeight,
              chairSize,
            ),
            Positioned.fill(
              child: Semantics(
                key: ValueKey('table-marker-${table.id}'),
                button: true,
                label:
                    '${table.code}, ${table.name}, ${table.capacity} kursi, ${table.statusLabel}',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showTableDetail(table),
                    borderRadius: _tableBorderRadius(table.shape),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [
                            Color(0xFFE3AD70),
                            Color(0xFFA55D35),
                            Color(0xFF71351F),
                          ],
                          stops: const [0, 0.56, 1],
                        ),
                        border: Border.all(
                          color: statusStyle.color,
                          width: 2.5,
                        ),
                        borderRadius: _tableBorderRadius(table.shape),
                        boxShadow: [
                          BoxShadow(
                            color: _espresso.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: EdgeInsets.all(contentPadding),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  table.code,
                                  style: GoogleFonts.poppins(
                                    color: _espresso,
                                    fontSize: codeFontSize,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(
                                  height: math.max(0.25, nameFontSize * 0.12),
                                ),
                                Text(
                                  table.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: _espresso.withValues(alpha: 0.9),
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(
                                  height: math.max(
                                    0.25,
                                    capacityFontSize * 0.12,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: _espresso.withValues(alpha: 0.78),
                                      size: iconSize,
                                    ),
                                    Text(
                                      '${table.capacity}',
                                      style: GoogleFonts.poppins(
                                        color: _espresso.withValues(
                                          alpha: 0.86,
                                        ),
                                        fontSize: capacityFontSize,
                                        fontWeight: FontWeight.w600,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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

  List<Widget> _buildTableChairs(
    int capacity,
    double tableWidth,
    double tableHeight,
    double chairSize,
  ) {
    final seatCount = capacity.clamp(1, 20).toInt();
    return List.generate(seatCount, (index) {
      final angle = (math.pi * 2 * index) / seatCount - math.pi / 2;
      final x = tableWidth / 2 + math.cos(angle) * tableWidth * 0.76;
      final y = tableHeight / 2 + math.sin(angle) * tableHeight * 0.84;
      return Positioned(
        left: x - chairSize / 2,
        top: y - chairSize * 0.66,
        child: Transform.rotate(
          angle: angle + math.pi / 2,
          child: SizedBox(
            width: chairSize,
            height: chairSize * 1.32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: chairSize * 0.04,
                  top: 0,
                  child: Container(
                    width: chairSize * 0.92,
                    height: chairSize * 0.5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE5AC71), Color(0xFF8D4729)],
                      ),
                      border: Border.all(
                        color: const Color(0xFF62341F),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(chairSize * 0.2),
                    ),
                  ),
                ),
                Positioned(
                  left: chairSize * 0.1,
                  top: chairSize * 0.46,
                  child: Container(
                    width: chairSize * 0.8,
                    height: chairSize * 0.38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF2C58D), Color(0xFFB5683D)],
                      ),
                      border: Border.all(
                        color: const Color(0xFF62341F),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(chairSize * 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: _espresso.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: chairSize * 0.2,
                  top: chairSize * 0.82,
                  child: SizedBox(
                    width: chairSize * 0.6,
                    height: chairSize * 0.36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        2,
                        (_) => Container(
                          width: chairSize * 0.1,
                          decoration: BoxDecoration(
                            color: const Color(0xFF62341F),
                            borderRadius: BorderRadius.circular(
                              chairSize * 0.05,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLegend() {
    final items = [
      _LegendItem('Tersedia', _statusStyleFor('available')),
      _LegendItem('Terisi', _statusStyleFor('occupied')),
      _LegendItem('Dipesan', _statusStyleFor('reserved')),
      _LegendItem('Tidak tersedia', _statusStyleFor('unavailable')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DCD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keterangan status',
            style: GoogleFonts.poppins(
              color: _espresso,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: item.style.soft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: item.style.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: GoogleFonts.poppins(
                            color: item.style.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityList(TableLayoutData data) {
    final rows = [
      _AvailabilityRow('Tersedia', data.summary.available, 'available'),
      _AvailabilityRow('Terisi', data.summary.occupied, 'occupied'),
      _AvailabilityRow('Dipesan', data.summary.reserved, 'reserved'),
      _AvailabilityRow(
        'Tidak tersedia',
        data.summary.unavailable,
        'unavailable',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan area',
            style: GoogleFonts.poppins(
              color: _espresso,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          ...rows.map((row) {
            final style = _statusStyleFor(row.status);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: style.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.label,
                      style: GoogleFonts.poppins(
                        color: _espresso.withValues(alpha: 0.76),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${row.total} meja',
                    style: GoogleFonts.poppins(
                      color: _espresso,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showTableDetail(CoffeeTableModel table) {
    final statusStyle = _statusStyleFor(table.status);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5D8CE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusStyle.soft,
                      border: Border.all(color: statusStyle.color, width: 2),
                      borderRadius: _tableBorderRadius(table.shape),
                    ),
                    child: Icon(
                      Icons.table_restaurant_rounded,
                      color: statusStyle.color,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.name,
                          style: GoogleFonts.poppins(
                            color: _espresso,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kode ${table.code}',
                          style: GoogleFonts.poppins(
                            color: _espresso.withValues(alpha: 0.52),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _espresso.withValues(alpha: 0.55),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statusStyle.soft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: statusStyle.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      table.statusLabel,
                      style: GoogleFonts.poppins(
                        color: statusStyle.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _detailRow(
                Icons.person_outline_rounded,
                'Kapasitas',
                '${table.capacity} kursi',
              ),
              if (table.statusUpdatedAt != null) ...[
                const SizedBox(height: 10),
                _detailRow(
                  Icons.update_rounded,
                  'Status diperbarui',
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
                    'id_ID',
                  ).format(table.statusUpdatedAt!.toLocal()),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'Status meja diatur oleh karyawan dan dapat berubah sewaktu-waktu.',
                style: GoogleFonts.poppins(
                  color: _espresso.withValues(alpha: 0.48),
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF805434), size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _espresso.withValues(alpha: 0.56),
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: _espresso,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  BorderRadius _tableBorderRadius(String shape) {
    switch (shape) {
      case 'round':
        return BorderRadius.circular(999);
      case 'rectangle':
        return BorderRadius.circular(8);
      default:
        return BorderRadius.circular(11);
    }
  }

  _TableStatusStyle _statusStyleFor(String status) {
    switch (status) {
      case 'available':
        return const _TableStatusStyle(Color(0xFF16856F), Color(0xFFE8F7F1));
      case 'occupied':
        return const _TableStatusStyle(Color(0xFFD9634D), Color(0xFFFFF0ED));
      case 'reserved':
        return const _TableStatusStyle(Color(0xFFBD7A24), Color(0xFFFFF6E5));
      default:
        return const _TableStatusStyle(Color(0xFF7A818C), Color(0xFFF1F3F5));
    }
  }

  _BackgroundStyle _backgroundStyleFor(String type) {
    switch (type) {
      case 'counter':
        return const _BackgroundStyle(
          foreground: Colors.white,
          background: Color(0xFF5D4037),
          border: Color(0xFF5D4037),
          minWidth: 66,
          minHeight: 24,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        );
      case 'window':
        return const _BackgroundStyle(
          foreground: Color(0xFF52728C),
          background: Color(0xFFE5F4FA),
          border: Color(0xFF8BB9D3),
          minWidth: 40,
          minHeight: 24,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        );
      case 'entrance':
        return const _BackgroundStyle(
          foreground: Color(0xFF72552E),
          background: Color(0xFFFFF7E9),
          border: Color(0xFFD3B27C),
          minWidth: 60,
          minHeight: 24,
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        );
      default:
        return const _BackgroundStyle(
          foreground: Color(0xFF705A52),
          background: Color(0xFFFFFFFF),
          border: Color(0xFFB8A69A),
          minWidth: 44,
          minHeight: 22,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        );
    }
  }
}

class _TableStatusStyle {
  const _TableStatusStyle(this.color, this.soft);

  final Color color;
  final Color soft;
}

class _BackgroundStyle {
  const _BackgroundStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.minWidth,
    required this.minHeight,
    required this.padding,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final double minWidth;
  final double minHeight;
  final EdgeInsets padding;
}

class _LegendItem {
  const _LegendItem(this.label, this.style);

  final String label;
  final _TableStatusStyle style;
}

class _AvailabilityRow {
  const _AvailabilityRow(this.label, this.total, this.status);

  final String label;
  final int total;
  final String status;
}

class _FloorGridPainter extends CustomPainter {
  const _FloorGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8D6E63).withValues(alpha: 0.09)
      ..strokeWidth = 1;
    final verticalStep = size.width * 0.05;
    final horizontalStep = size.height * 0.075;

    for (var x = 0.0; x <= size.width; x += verticalStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += horizontalStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorGridPainter oldDelegate) => false;
}
