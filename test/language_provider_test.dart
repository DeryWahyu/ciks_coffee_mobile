import 'package:ciks_coffee_mobile/providers/language_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LanguageProvider', () {
    test('initializes default to Indonesian', () {
      final provider = LanguageProvider();
      expect(provider.isEnglish, isFalse);
      expect(provider.tr('Beranda'), 'Beranda');
      expect(provider.tr('Profil'), 'Profil');
      expect(provider.tr('Ketersediaan meja'), 'Ketersediaan meja');
    });

    test('translates key terms to English when isEnglish is true', () async {
      final provider = LanguageProvider();
      await provider.toggleLanguage(true);

      expect(provider.isEnglish, isTrue);

      // Bottom Nav
      expect(provider.tr('Beranda'), 'Home');
      expect(provider.tr('Keranjang'), 'Cart');
      expect(provider.tr('Status'), 'Status');
      expect(provider.tr('Riwayat'), 'History');
      expect(provider.tr('Profil'), 'Profile');

      // Profile Screen
      expect(provider.tr('Keluar dari Akun'), 'Log Out from Account');
      expect(provider.tr('Informasi Pribadi'), 'Personal Information');
      expect(provider.tr('Nomor Telepon'), 'Phone Number');
      expect(provider.tr('Tentang Aplikasi'), 'About App');
      expect(provider.tr('Kebijakan Privasi'), 'Privacy Policy');
      expect(provider.tr('Bantuan'), 'Help');
      expect(provider.tr('PENGGUNA'), 'CUSTOMER');

      // Home Screen
      expect(provider.tr('Kategori'), 'Categories');
      expect(provider.tr('Menu Pilihan'), 'Featured Menu');
      expect(provider.tr('Cari meja yang tersedia'), 'Find an available table');

      // Table Availability
      expect(provider.tr('Ketersediaan meja'), 'Table Availability');
      expect(provider.tr('Tersedia'), 'Available');
      expect(provider.tr('Terisi'), 'Occupied');
      expect(provider.tr('Dipesan'), 'Reserved');
      expect(provider.tr('Tidak tersedia'), 'Unavailable');

      // Auth
      expect(provider.tr('Masuk'), 'Login');
      expect(provider.tr('Daftar'), 'Register');
    });

    test('reverts back to Indonesian when toggleLanguage(false)', () async {
      final provider = LanguageProvider();
      await provider.toggleLanguage(true);
      expect(provider.isEnglish, isTrue);

      await provider.toggleLanguage(false);
      expect(provider.isEnglish, isFalse);
      expect(provider.tr('Beranda'), 'Beranda');
      expect(provider.tr('Keluar dari Akun'), 'Keluar dari Akun');
    });
  });
}
