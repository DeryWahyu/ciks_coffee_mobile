import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'coffee_overlays.dart';

class QrisPaymentSheet extends StatefulWidget {
  const QrisPaymentSheet({
    super.key,
    required this.total,
    required this.language,
    required this.apiService,
  });

  final String total;
  final LanguageProvider language;
  final ApiService apiService;

  @override
  State<QrisPaymentSheet> createState() => _QrisPaymentSheetState();
}

class _QrisPaymentSheetState extends State<QrisPaymentSheet> {
  late Future<Map<String, dynamic>> _qris = widget.apiService.getQrisImage();
  File? _proof;
  bool _picking = false;
  String? _error;

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
        onPressed: _proof == null || _picking
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
                    errorBuilder: (_, error, stack) => _qrisError(english),
                  ),
                );
              }
              return _qrisError(english);
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

  Widget _qrisError(bool english) => Container(
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
          english ? 'QRIS could not be loaded.' : 'QRIS belum dapat dimuat.',
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
