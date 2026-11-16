import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/table_layout_model.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../widgets/coffee_overlays.dart';
import '../widgets/floor_plan_view.dart';

class TableAvailabilityScreen extends StatefulWidget {
  const TableAvailabilityScreen({
    super.key,
    this.apiService,
    this.pollingInterval = const Duration(seconds: 8),
    this.backgroundImageProvider,
  });

  final ApiService? apiService;
  final Duration pollingInterval;
  final ImageProvider? backgroundImageProvider;

  @override
  State<TableAvailabilityScreen> createState() =>
      _TableAvailabilityScreenState();
}

class _TableAvailabilityScreenState extends State<TableAvailabilityScreen>
    with WidgetsBindingObserver {
  late final ApiService _apiService;
  final _transform = TransformationController();
  final _visibleLayout = ValueNotifier<TableLayoutData?>(null);
  Timer? _pollingTimer;
  TableLayoutData? _data;
  String? _errorMessage;
  bool _isLoading = true, _isRefreshing = false, _isRequestInFlight = false;
  DateTime? _lastRefreshedAt;
  Size _viewportSize = Size.zero;

  bool get _english => context.read<LanguageProvider?>()?.isEnglish == true;
  String _text(String id, String en) => _english ? en : id;
  String _status(String value) => _english
      ? switch (value) {
          'available' => 'Available',
          'occupied' => 'Occupied',
          'reserved' => 'Reserved',
          _ => 'Unavailable',
        }
      : tableStatusLabel(value);

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
    _pollingTimer?.cancel();
    _transform.dispose();
    _visibleLayout.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLayout(silent: _data != null);
      _startPolling();
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  void _startPolling() {
    _pollingTimer ??= Timer.periodic(
      widget.pollingInterval,
      (_) => _loadLayout(silent: true),
    );
  }

  Future<void> _loadLayout({bool silent = false}) async {
    if (_isRequestInFlight) return;
    _isRequestInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _isLoading = _data == null;
        _isRefreshing = _data != null;
        _errorMessage = null;
      });
    }
    try {
      final result = await _apiService.getTableLayout();
      if (!mounted) return;
      if (result['success'] == true && result['data'] is TableLayoutData) {
        final data = result['data'] as TableLayoutData;
        setState(() {
          _data = data;
          _lastRefreshedAt = DateTime.now().toUtc().add(
            const Duration(hours: 7),
          );
          _errorMessage = null;
        });
        _visibleLayout.value = data;
      } else {
        setState(
          () => _errorMessage =
              result['message']?.toString() ?? 'Denah belum dapat dimuat.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = _text(
            'Koneksi terputus. Silakan coba lagi.',
            'Connection lost. Please try again.',
          ),
        );
      }
    } finally {
      _isRequestInFlight = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider?>();
    final data = _data;
    return Scaffold(
      backgroundColor: FloorPlanPalette.cream,
      appBar: AppBar(
        backgroundColor: FloorPlanPalette.cream,
        foregroundColor: FloorPlanPalette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          _text('Ketersediaan meja', 'Table availability'),
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _text('Muat ulang', 'Refresh'),
            onPressed: _isLoading || _isRefreshing ? null : () => _loadLayout(),
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
          ? _initialState()
          : RefreshIndicator(
              color: FloorPlanPalette.ink,
              onRefresh: () => _loadLayout(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _intro(data),
                          const SizedBox(height: 16),
                          _summary(data),
                          const SizedBox(height: 16),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'CiksSans',
                                  fontSize: 12,
                                  color: CoffeeColors.danger,
                                ),
                              ),
                            ),
                          _mapCard(data),
                          const SizedBox(height: 16),
                          _tableList(data),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _initialState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _isLoading
          ? const CircularProgressIndicator(color: FloorPlanPalette.ink)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.table_restaurant_outlined,
                  color: FloorPlanPalette.muted,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  _text(
                    'Denah belum dapat dimuat',
                    'Floor plan could not load',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'CiksSans',
                    fontWeight: FontWeight.w700,
                    color: FloorPlanPalette.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'CiksSans',
                    color: FloorPlanPalette.muted,
                  ),
                ),
                const SizedBox(height: 20),
                CoffeeButton(
                  label: _text('Coba lagi', 'Try again'),
                  onPressed: () => _loadLayout(),
                ),
              ],
            ),
    ),
  );

  Widget _intro(TableLayoutData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _text('RUANG & OPERASIONAL', 'SPACE & AVAILABILITY'),
        style: const TextStyle(
          fontFamily: 'CiksSans',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: FloorPlanPalette.muted,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        data.layout.name,
        style: const TextStyle(
          fontFamily: 'CiksSans',
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: FloorPlanPalette.ink,
        ),
      ),
      if (_lastRefreshedAt != null) ...[
        const SizedBox(height: 5),
        Text(
          '${_text('Diperbarui', 'Updated')} ${DateFormat('HH:mm').format(_lastRefreshedAt!)} · ${_text('Otomatis', 'Automatic updates')}',
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 11,
            color: FloorPlanPalette.muted,
          ),
        ),
      ],
    ],
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: FloorPlanPalette.line),
  );

  Widget _summary(TableLayoutData data) {
    final counts = {
      'available': data.summary.available,
      'occupied': data.summary.occupied,
      'reserved': data.summary.reserved,
      'unavailable': data.summary.unavailable,
    };
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text('Keterangan status', 'Status legend'),
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FloorPlanPalette.muted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _stat('Total', data.summary.total),
              for (final entry in counts.entries)
                _stat(_status(entry.key), entry.value, status: entry.key),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int count, {String? status}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (status != null) ...[_dot(status), const SizedBox(width: 6)],
      Flexible(
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 11,
            color: FloorPlanPalette.muted,
          ),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        '$count',
        style: const TextStyle(
          fontFamily: 'CiksSans',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FloorPlanPalette.ink,
        ),
      ),
    ],
  );

  Widget _dot(String status) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: FloorPlanPalette.status(status),
    ),
  );

  String? _backgroundUrl(FloorLayoutModel layout) {
    final url = layout.backgroundImage?.url;
    if (url == null) return null;
    return Uri.parse('${_apiService.hostUrl}/').resolve(url).toString();
  }

  Widget _mapCard(TableLayoutData data) => Container(
    decoration: _cardDecoration,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _text('Denah kedai', 'Coffee shop floor plan'),
                style: const TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FloorPlanPalette.ink,
                ),
              ),
              Text(
                _text('Tampak atas', 'Top view'),
                style: const TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 10,
                  color: FloorPlanPalette.muted,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: FloorPlanPalette.line),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(
              constraints.maxWidth,
              constraints.maxWidth *
                  data.layout.canvasHeight /
                  data.layout.canvasWidth,
            );
            if (_viewportSize != size) {
              final shouldReset = _viewportSize != Size.zero;
              _viewportSize = size;
              if (shouldReset) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _viewportSize == size) {
                    _transform.value = Matrix4.identity();
                  }
                });
              }
            }
            return SizedBox(
              width: size.width,
              height: size.height,
              child: InteractiveViewer(
                key: const ValueKey('floor-plan-viewer'),
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                boundaryMargin: EdgeInsets.zero,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: FloorPlanView(
                    data: data,
                    onTableTap: _showTableDetail,
                    backgroundUrl: _backgroundUrl(data.layout),
                    backgroundImageProvider: widget.backgroundImageProvider,
                    english: _english,
                  ),
                ),
              ),
            );
          },
        ),
        const Divider(height: 1, thickness: 1, color: FloorPlanPalette.line),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  _text(
                    'Ketuk meja untuk melihat detail status.',
                    'Tap a table to see its status.',
                  ),
                  style: const TextStyle(
                    fontFamily: 'CiksSans',
                    fontSize: 10,
                    color: FloorPlanPalette.muted,
                  ),
                ),
              ),
              ValueListenableBuilder<Matrix4>(
                valueListenable: _transform,
                builder: (context, matrix, _) {
                  final scale = matrix.getMaxScaleOnAxis();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('floor-zoom-out'),
                        tooltip: _text('Perkecil', 'Zoom out'),
                        onPressed: scale <= 1.001 ? null : () => _zoom(.8),
                        icon: const Icon(Icons.remove, size: 16),
                      ),
                      Text(
                        '${(scale * 100).round()}%',
                        style: const TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 11,
                          color: FloorPlanPalette.muted,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('floor-zoom-in'),
                        tooltip: _text('Perbesar', 'Zoom in'),
                        onPressed: scale >= 3.999 ? null : () => _zoom(1.25),
                        icon: const Icon(Icons.add, size: 16),
                      ),
                      TextButton(
                        key: const ValueKey('floor-zoom-fit'),
                        onPressed: () => _transform.value = Matrix4.identity(),
                        child: Text(
                          _text('Pas', 'Fit'),
                          style: const TextStyle(
                            fontFamily: 'CiksSans',
                            fontSize: 11,
                            color: FloorPlanPalette.ink,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _zoom(double factor) {
    final old = _transform.value, scale = old.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(1.0, 4.0), ratio = next / scale;
    final center = _viewportSize.center(Offset.zero);
    final x = (center.dx - (center.dx - old.storage[12]) * ratio).clamp(
      _viewportSize.width * (1 - next),
      0.0,
    );
    final y = (center.dy - (center.dy - old.storage[13]) * ratio).clamp(
      _viewportSize.height * (1 - next),
      0.0,
    );
    _transform.value = Matrix4.diagonal3Values(next, next, 1)
      ..setTranslationRaw(x, y, 0);
  }

  Widget _tableList(TableLayoutData data) => Container(
    decoration: _cardDecoration,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('table-list'),
        title: Text(
          _text('Daftar meja', 'Table list'),
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FloorPlanPalette.ink,
          ),
        ),
        subtitle: Text(
          _text(
            'Pilih meja untuk melihat detail.',
            'Choose a table to see its details.',
          ),
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 11,
            color: FloorPlanPalette.muted,
          ),
        ),
        children: data.tables.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _text(
                      'Meja belum ditambahkan.',
                      'No tables have been added.',
                    ),
                    style: const TextStyle(fontFamily: 'CiksSans'),
                  ),
                ),
              ]
            : [
                for (final table in data.tables)
                  ListTile(
                    onTap: () => _showTableDetail(table),
                    title: Text(
                      '${table.code} · ${table.name}',
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${table.capacity} ${_text('kursi', 'seats')}',
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        fontSize: 11,
                      ),
                    ),
                    trailing: Semantics(
                      label: _status(table.status),
                      child: _dot(table.status),
                    ),
                  ),
              ],
      ),
    ),
  );

  void _showTableDetail(CoffeeTableModel table) {
    showCoffeeSheet<void>(
      context: context,
      builder: (context) => ValueListenableBuilder<TableLayoutData?>(
        valueListenable: _visibleLayout,
        builder: (context, data, _) {
          CoffeeTableModel? current;
          for (final candidate in data?.tables ?? <CoffeeTableModel>[]) {
            if (candidate.id == table.id) {
              current = candidate;
              break;
            }
          }
          return CoffeeSheet(
            title: current?.name ?? table.name,
            subtitle: '${_text('Kode', 'Code')} ${table.code}',
            dismissLabel: _text('Tutup', 'Close'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (current == null)
                  Text(
                    _text(
                      'Meja ini sudah tidak tersedia.',
                      'This table is no longer available.',
                    ),
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      color: FloorPlanPalette.muted,
                    ),
                  )
                else ...[
                  _detailRow(
                    _text('Status', 'Status'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dot(current.status),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _status(current.status),
                            style: const TextStyle(
                              fontFamily: 'CiksSans',
                              fontWeight: FontWeight.w600,
                              color: FloorPlanPalette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _detailRow(
                    _text('Kapasitas', 'Capacity'),
                    Text(
                      '${current.capacity} ${_text('kursi', 'seats')}',
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        color: FloorPlanPalette.ink,
                      ),
                    ),
                  ),
                  _detailRow(
                    _text('Bentuk', 'Shape'),
                    Text(
                      switch (current.shape) {
                        'round' => _text('Bulat', 'Round'),
                        'rectangle' => _text('Persegi panjang', 'Rectangle'),
                        _ => _text('Persegi', 'Square'),
                      },
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        color: FloorPlanPalette.ink,
                      ),
                    ),
                  ),
                  if (current.statusUpdatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${_text('Diperbarui', 'Updated')} ${DateFormat('dd/MM/yyyy HH:mm').format(current.statusUpdatedAt!.toUtc().add(const Duration(hours: 7)))}',
                        style: const TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 11,
                          color: FloorPlanPalette.muted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'CiksSans',
              color: FloorPlanPalette.muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: value),
      ],
    ),
  );
}
