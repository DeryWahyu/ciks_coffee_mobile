import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../services/user_message.dart';
import 'coffee_overlays.dart';

class QrisPaymentSheet extends StatefulWidget {
  const QrisPaymentSheet({
    super.key,
    required this.total,
    required this.language,
    required this.apiService,
    this.expiresAt,
    this.onCancel,
    this.onExpired,
    this.items = const [],
    this.allowPayment = true,
  });

  final String total;
  final LanguageProvider language;
  final ApiService apiService;
  final DateTime? expiresAt;
  final Future<Map<String, dynamic>> Function()? onCancel;
  final VoidCallback? onExpired;
  final List<Map<String, dynamic>> items;
  final bool allowPayment;

  @override
  State<QrisPaymentSheet> createState() => _QrisPaymentSheetState();
}

class _QrisPaymentSheetState extends State<QrisPaymentSheet> {
  late Future<Map<String, dynamic>> _qris = widget.apiService.getQrisImage();
  File? _proof;
  bool _picking = false;
  String? _error;
  Timer? _expiryTimer;
  bool _cancelling = false;
  bool _deadlineReached = false;
  bool get _expired =>
      _deadlineReached ||
      !widget.allowPayment ||
      (widget.expiresAt != null && !widget.expiresAt!.isAfter(DateTime.now()));

  @override
  void initState() {
    super.initState();
    if (widget.expiresAt != null) {
      _expiryTimer = Timer(widget.expiresAt!.difference(DateTime.now()), () {
        if (!mounted) return;
        setState(() => _deadlineReached = true);
        widget.onExpired?.call();
      });
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CoffeeDialog(
        title: 'Batalkan pembayaran?',
        message:
            'Pilih batal hanya jika kamu belum membayar. Jika sudah membayar, unggah bukti agar kasir dapat memeriksanya.',
        actions: [
          CoffeeButton(
            label: 'Saya belum membayar, batalkan',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          CoffeeButton(
            label: 'Kembali',
            secondary: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    Map<String, dynamic> cancelled;
    try {
      cancelled = await widget.onCancel!();
    } catch (_) {
      cancelled = {
        'success': false,
        'message':
            'Pembatalan belum dapat dipastikan. Periksa menu Status sebelum mencoba lagi.',
      };
    }
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (cancelled['success'] == true) {
      Navigator.of(context).pop('');
    } else {
      setState(
        () => _error = UserMessage.display(
          cancelled['message'],
          fallback:
              'Pembatalan belum berhasil. Periksa menu Status sebelum mencoba lagi.',
        ),
      );
    }
  }

  Future<void> _pickProof() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (mounted && picked != null) setState(() => _proof = File(picked.path));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = widget.language.isEnglish
              ? 'Could not open this image. Please try again.'
              : 'Gambar tidak dapat dibuka. Silakan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.language.isEnglish;
    return CoffeeSheet(
      title: english ? 'Pay with QRIS' : 'Bayar dengan QRIS',
      subtitle: english
          ? 'Scan, pay, then upload your payment proof.'
          : 'Pindai, bayar, lalu unggah bukti pembayaranmu.',
      dismissLabel: english ? 'Close' : 'Tutup',
      footer: CoffeeButton(
        key: const ValueKey('qris-submit'),
        label: _proof == null
            ? (english
                  ? 'Choose payment proof first'
                  : 'Pilih bukti pembayaran dahulu')
            : (english ? 'Send order' : 'Kirim Pesanan'),
        icon: Icons.arrow_forward_rounded,
        onPressed: _proof == null || _picking || _cancelling
            ? null
            : () => Navigator.of(context).pop(_proof!.path),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CoffeeColors.cream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  english ? 'Amount to pay' : 'Total yang dibayar',
                  style: const TextStyle(
                    fontFamily: 'CiksSans',
                    fontSize: 12,
                    color: CoffeeColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.total,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'CiksSans',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: CoffeeColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final item in widget.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${item['product_name'] ?? 'Produk'} × ${item['quantity']}',
                style: const TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 12,
                  color: CoffeeColors.muted,
                ),
              ),
            ),
          if (widget.expiresAt != null) ...[
            Text(
              !widget.allowPayment
                  ? 'Jangan lakukan pembayaran baru. Unggah bukti pembayaran sebelumnya untuk pemeriksaan kasir.'
                  : _expired
                  ? 'Waktu pembayaran berakhir. Jangan lakukan pembayaran baru. Jika sudah membayar, unggah bukti untuk pemeriksaan kasir.'
                  : 'Harga dikunci dan stok direservasi sampai ${widget.expiresAt!.toLocal().hour.toString().padLeft(2, '0')}:${widget.expiresAt!.toLocal().minute.toString().padLeft(2, '0')}.',
              style: const TextStyle(
                fontFamily: 'CiksSans',
                fontSize: 12,
                color: CoffeeColors.muted,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!_expired)
            FutureBuilder<Map<String, dynamic>>(
              future: _qris,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 208,
                    child: Center(
                      child: CircularProgressIndicator(color: CoffeeColors.ink),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data?['success'] == true) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: CoffeeColors.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Image.network(
                      data!['image_url'],
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stack) => _qrisError(
                        english,
                        'Gambar QRIS gagal dimuat. Periksa koneksi lalu coba lagi atau minta bantuan kasir.',
                      ),
                    ),
                  );
                }
                return _qrisError(english, data?['message']);
              },
            ),
          const SizedBox(height: 20),
          Text(
            english ? 'Payment proof' : 'Bukti pembayaran',
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CoffeeColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            english
                ? 'Upload a clear photo or screenshot, up to 3 MB.'
                : 'Unggah foto atau tangkapan layar yang jelas, maksimal 3 MB.',
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 12,
              height: 1.5,
              color: CoffeeColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          if (_proof == null)
            InkWell(
              key: const ValueKey('qris-pick-proof'),
              onTap: _picking ? null : _pickProof,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: CoffeeColors.cream,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CoffeeColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: CoffeeColors.ink,
                      size: 30,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _picking
                          ? (english
                                ? 'Opening gallery...'
                                : 'Membuka galeri...')
                          : (english
                                ? 'Choose from gallery'
                                : 'Pilih dari galeri'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        fontWeight: FontWeight.w600,
                        color: CoffeeColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_proof!, height: 150, fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
            CoffeeButton(
              label: english ? 'Change photo' : 'Ganti foto',
              secondary: true,
              icon: Icons.photo_outlined,
              onPressed: _picking ? null : _pickProof,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'CiksSans',
                color: CoffeeColors.danger,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.onCancel != null)
            TextButton(
              onPressed: _cancelling ? null : _cancel,
              child: const Text('Belum membayar? Batalkan sesi pembayaran'),
            ),
          Text(
            english
                ? 'Your payment proof will be reviewed by the cashier before your order is prepared.'
                : 'Kasir akan memeriksa bukti pembayaran sebelum pesananmu dibuat.',
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 12,
              height: 1.6,
              color: CoffeeColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrisError(bool english, [Object? reason]) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CoffeeColors.cream,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.qr_code_2_rounded,
          size: 40,
          color: CoffeeColors.muted,
        ),
        const SizedBox(height: 10),
        Text(
          widget.language.tr(
            UserMessage.display(
              reason,
              fallback:
                  'QRIS belum dapat dimuat. Periksa koneksi atau minta bantuan kasir.',
            ),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'CiksSans',
            color: CoffeeColors.muted,
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: () =>
              setState(() => _qris = widget.apiService.getQrisImage()),
          child: Text(english ? 'Try again' : 'Coba lagi'),
        ),
      ],
    ),
  );
}
