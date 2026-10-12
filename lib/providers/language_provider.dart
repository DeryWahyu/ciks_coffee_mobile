import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const String _prefKey = 'selected_language_english';
  bool _isEnglish = false;

  bool get isEnglish => _isEnglish;

  LanguageProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null && saved != _isEnglish) {
        _isEnglish = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleLanguage(bool isEnglish) async {
    _isEnglish = isEnglish;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, isEnglish);
    } catch (_) {}
  }

  String tr(String id) {
    if (!_isEnglish) return id;

    final Map<String, String> translations = {
      // General & Actions
      'Batal': 'Cancel',
      'Keluar': 'Logout',
      'Tutup': 'Close',
      'Coba Lagi': 'Try Again',
      'Coba lagi': 'Try Again',
      'Kembali': 'Back',
      'Simpan': 'Save',
      'Selesai': 'Completed',
      'Ya': 'Yes',
      'Tidak': 'No',
      'OK': 'OK',
      'Muat ulang': 'Refresh',
      'Total': 'Total',
      'Total: ': 'Total: ',
      'Total:': 'Total:',
      'item': 'item(s)',
      'Item': 'Item(s)',
      'Pesan Sekarang': 'Order Now',
      'Habis': 'Sold Out',
      'Kategori': 'Categories',
      'Menu Pilihan': 'Featured Menu',

      // Auth
      'Masuk': 'Login',
      'Daftar': 'Register',
      'Selamat Datang Kembali': 'Welcome Back',
      'Masuk ke akun untuk mulai memesan': 'Sign in to start ordering',
      'Daftar Akun Baru': 'Create New Account',
      'Daftar untuk menikmati kopi favoritmu':
          'Sign up to enjoy your favorite coffee',
      'Nama Lengkap': 'Full Name',
      'Kata Sandi': 'Password',
      'Minimal 8 karakter': 'Minimum 8 characters',
      'Belum punya akun? ': 'Don\'t have an account? ',
      'Daftar Sekarang': 'Register Now',
      'Sudah punya akun? ': 'Already have an account? ',
      'Masuk di Sini': 'Sign In Here',
      'Semua kolom harus diisi!': 'All fields must be filled!',
      'Format email tidak valid!': 'Invalid email format!',
      'Password minimal 8 karakter!': 'Password must be at least 8 characters!',
      'Pendaftaran berhasil! Silakan login.':
          'Registration successful! Please login.',

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
      'Ukuran reguler': 'Regular size',
      'Ukuran lebih kecil': 'Smaller size',
      'Original size': 'Regular size',
      'Smaller size': 'Smaller size',
      'ditambahkan ke keranjang': 'added to cart',
      'Tidak ada produk ditemukan.': 'No products found.',
      'Selamat Pagi': 'Good Morning',
      'Selamat Siang': 'Good Afternoon',
      'Selamat Sore': 'Good Evening',
      'Selamat Malam': 'Good Evening',
      'Selamat Pagi,': 'Good Morning,',
      'Selamat Siang,': 'Good Afternoon,',
      'Selamat Sore,': 'Good Evening,',
      'Selamat Malam,': 'Good Evening,',
      'Nikmati kopi\nterbaik kami': 'Enjoy our\nfinest coffee',
      'Cari meja yang tersedia': 'Find an available table',
      'Lihat denah dan status meja secara langsung':
          'View floor plan and live table availability',
      'Deskripsi produk belum tersedia.':
          'Product description is not available yet.',

      // Table Availability Screen
      'Ketersediaan meja': 'Table Availability',
      'Denah belum dapat dimuat': 'Floor plan could not be loaded',
      'Silakan coba lagi dalam beberapa saat.':
          'Please try again in a moment.',
      'meja tersedia': 'tables available',
      'dari': 'out of',
      'meja yang sedang ditampilkan': 'tables currently shown',
      'Diperbarui': 'Updated',
      'otomatis setiap 15 detik': 'auto-refreshed every 15s',
      'Denah ketersediaan': 'Availability Floor Plan',
      'Ketuk meja untuk melihat detail status.':
          'Tap any table to view status details.',
      'Keterangan status': 'Status Legend',
      'Ringkasan area': 'Area Summary',
      'Tersedia': 'Available',
      'Terisi': 'Occupied',
      'Dipesan': 'Reserved',
      'Tidak tersedia': 'Unavailable',
      'Kapasitas': 'Capacity',
      'kursi': 'seats',
      'Kode': 'Code',
      'Status diperbarui': 'Status updated',
      'Status meja diatur oleh karyawan dan dapat berubah sewaktu-waktu.':
          'Table status is managed by staff and may change at any time.',

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
      'PENGGUNA': 'CUSTOMER',
      'KARYAWAN': 'STAFF',
      'PEMILIK': 'OWNER',

      // Cart & Checkout
      'Keranjang Kosong': 'Cart is Empty',
      'Yuk, pilih menu favoritmu!': 'Let\'s choose your favorite menu!',
      'Mulai belanja untuk menambahkan item ke keranjang.':
          'Start shopping to add items to cart.',
      'Mulai Belanja': 'Start Shopping',
      'Pembayaran:': 'Payment:',
      'Pilih Metode Pembayaran': 'Select Payment Method',
      'Uang Tunai': 'Cash',
      'Pesanan Berhasil!': 'Order Successful!',
      'Pesanan berhasil dibuat!': 'Order successfully created!',
      'No.': 'Order #',
      'No. ': 'Order # ',
      'Bukti Pembayaran': 'Payment Proof',
      'Pembayaran QRIS': 'QRIS Payment',
      'Upload Bukti Transfer': 'Upload Transfer Proof',
      'Ketuk untuk pilih screenshot bukti transfer':
          'Tap to select transfer proof screenshot',
      'Bukti terpilih': 'Proof selected',
      'Upload bukti terlebih dahulu': 'Upload payment proof first',
      'Kirim Pesanan & Bukti Transfer': 'Submit Order & Proof',
      'QRIS belum tersedia': 'QRIS is currently not available',
      'Ambil dari Kamera': 'Take from Camera',
      'Pilih dari Galeri': 'Choose from Gallery',

      // Order Status
      'Pesanan Aktif': 'Active Orders',
      'Order tracker': 'Order tracker',
      'Lacak pesananmu': 'Track your order',
      'Menunggu Konfirmasi': 'Waiting Confirmation',
      'Sedang Dibuat': 'Being Prepared',
      'Siap Diambil': 'Ready to Pickup',
      'Belum ada pesanan aktif.': 'No active orders.',
      'Tidak Ada Pesanan Aktif': 'No Active Orders',
      'Konfirmasi Pengambilan': 'Confirm Pickup',
      'Apakah Anda yakin sudah mengambil pesanan ini?':
          'Are you sure you have picked up this order?',
      'Menunggu verifikasi admin': 'Waiting for admin verification',
      'Pesanan Telah Diambil': 'Order Picked Up',
      'Sudah Diambil': 'Picked Up',
      'Belum': 'Not Yet',
      'pesanan aktif': 'active orders',

      // History
      'Riwayat Pesanan': 'Order History',
      'Order History': 'Order History',
      'Tidak ada riwayat pesanan.': 'No order history.',
      'Belum Ada Riwayat': 'No History Yet',
      'Detail Pesanan': 'Order Details',
      'Order Details': 'Order Details',
      'Metode Pembayaran': 'Payment Method',
      'Payment Method': 'Payment Method',
      'Pesanan': 'Orders',
      'Orders': 'Orders',
    };

    return translations[id] ?? id;
  }
}
