import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  bool _isEnglish = false;

  bool get isEnglish => _isEnglish;

  void toggleLanguage(bool isEnglish) {
    _isEnglish = isEnglish;
    notifyListeners();
  }

  String tr(String id) {
    if (!_isEnglish) return id;

    final Map<String, String> translations = {
      // General
      'Batal': 'Cancel',
      'Keluar': 'Logout',
      'Tutup': 'Close',
      'Coba Lagi': 'Try Again',
      'Kembali': 'Back',
      'Simpan': 'Save',
      'Selesai': 'Completed',
      'Ya': 'Yes',
      'Tidak': 'No',

      // Bottom Navigation
      'Beranda': 'Home',
      'Keranjang': 'Cart',
      'Status': 'Status',
      'Riwayat': 'History',
      'Profil': 'Profile',

      // Home Screen
      'Semua': 'All',
      'Mau minum & makan apa hari ini?':
          'What would you like to drink & eat today?',
      'Pilih Varian': 'Select Variant',
      'ditambahkan ke keranjang': 'added to cart',
      'Tidak ada produk ditemukan.': 'No products found.',
      'Selamat Pagi,': 'Good Morning,',
      'Selamat Siang,': 'Good Afternoon,',
      'Selamat Sore,': 'Good Evening,',
      'Selamat Malam,': 'Good Night,',

      // Profile Screen
      'Apakah kamu yakin ingin keluar dari akun ini?':
          'Are you sure you want to log out of this account?',
      'Tentang Aplikasi': 'About App',
      'Versi 1.0.0': 'Version 1.0.0',
      'Aplikasi pemesanan kopi Ciks Coffee.\nNikmati kopi favoritmu dengan mudah!':
          'Ciks Coffee ordering app.\nEnjoy your favorite coffee easily!',
      'Bahasa': 'Language',
      'Gagal memuat profil.': 'Failed to load profile.',
      'AKUN': 'ACCOUNT',
      'Informasi Pribadi': 'Personal Information',
      'Nomor Telepon': 'Phone Number',
      'Belum diatur': 'Not set',
      'PREFERENSI': 'PREFERENCES',
      'Notifikasi': 'Notifications',
      'Aktif': 'On',
      'Nonaktif': 'Off',
      'LAINNYA': 'OTHERS',
      'Kebijakan Privasi': 'Privacy Policy',
      'Halaman kebijakan privasi': 'Privacy policy page',
      'Bantuan': 'Help',
      'Hubungi kami di support@cikscoffee.com':
          'Contact us at support@cikscoffee.com',
      'Keluar dari Akun': 'Log Out from Account',
      'Nama': 'Name',
      'Telepon': 'Phone',
      'Peran': 'Role',

      // Cart & Checkout
      'Keranjang Kosong': 'Cart is Empty',
      'Yuk, pilih menu favoritmu!': 'Let\'s choose your favorite menu!',
      'Mulai belanja untuk menambahkan item ke keranjang.':
          'Start shopping to add items to cart.',
      'Mulai Belanja': 'Start Shopping',
      'Total': 'Total',
      'Total: ': 'Total: ',
      'Checkout': 'Checkout',
      'Pembayaran:': 'Payment:',
      'Pesan Sekarang': 'Order Now',
      'Pilih Metode Pembayaran': 'Select Payment Method',
      'Uang Tunai': 'Cash',
      'Pesanan Berhasil!': 'Order Successful!',
      'Pesanan berhasil dibuat!': 'Order successfully created!',
      'No. ': 'No. ',
      'Bukti Pembayaran': 'Payment Proof',
      'Pembayaran QRIS': 'QRIS Payment',
      'Upload Bukti Transfer': 'Upload Transfer Proof',
      'Ketuk untuk pilih screenshot bukti transfer':
          'Tap to select transfer proof screenshot',
      'Bukti terpilih': 'Proof selected',
      'Upload bukti terlebih dahulu': 'Upload proof first',
      'Kirim Pesanan & Bukti Transfer': 'Submit Order & Proof',
      'QRIS belum tersedia': 'QRIS not available yet',
      'OK': 'OK',
      'Ambil dari Kamera': 'Take from Camera',
      'Pilih dari Galeri': 'Choose from Gallery',

      // Order Status
      'Pesanan Aktif': 'Active Orders',
      'Menunggu Konfirmasi': 'Waiting Confirmation',
      'Sedang Dibuat': 'Being Prepared',
      'Siap Diambil': 'Ready to Pickup',
      'Belum ada pesanan aktif.': 'No active orders.',
      'Konfirmasi Pengambilan': 'Confirm Pickup',
      'Apakah Anda yakin sudah mengambil pesanan ini?':
          'Are you sure you have picked up this order?',
      'Menunggu verifikasi admin': 'Waiting for admin verification',
      'Item': 'Item(s)',

      // History
      'Riwayat Pesanan': 'Order History',
      'Tidak ada riwayat pesanan.': 'No order history.',
    };

    return translations[id] ?? id;
  }
}
