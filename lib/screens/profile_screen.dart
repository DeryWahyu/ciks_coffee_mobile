import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  UserModel? _user;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getProfile();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _user = UserModel.fromJson(result['data']);
        }
      });
    }
  }

  void _logout() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.tr('Keluar'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4A3022),
          ),
        ),
        content: Text(
          lang.tr('Apakah kamu yakin ingin keluar dari akun ini?'),
          style: GoogleFonts.inter(color: const Color(0xFF4A3022)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              lang.tr('Batal'),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _apiService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              lang.tr('Keluar'),
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A3022).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.coffee,
                  color: Color(0xFF4A3022),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ciks Coffee',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.tr('Versi 1.0.0'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.tr(
                  'Aplikasi pemesanan kopi Ciks Coffee.\nNikmati kopi favoritmu dengan mudah!',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4A3022).withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A3022),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    lang.tr('Tutup'),
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A3022).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Color(0xFF4A3022),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.tr('Kebijakan Privasi'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.isEnglish
                    ? 'Your privacy is important to us. We collect your data only for order processing and improving service quality. We do not share your data with third parties without your explicit consent.'
                    : 'Privasi Anda penting bagi kami. Kami mengumpulkan data Anda hanya untuk keperluan pemrosesan pesanan dan peningkatan layanan. Kami tidak membagikan data Anda kepada pihak ketiga tanpa izin Anda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4A3022).withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A3022),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    lang.tr('Tutup'),
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A3022).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Color(0xFF4A3022),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.tr('Bantuan'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.isEnglish
                    ? 'Need help with your order or the application? Contact our customer support team.\n\nEmail: support@cikscoffee.com\nPhone: +62 812-3456-7890'
                    : 'Butuh bantuan terkait pesanan atau penggunaan aplikasi? Hubungi tim layanan pelanggan kami.\n\nEmail: support@cikscoffee.com\nTelepon: +62 812-3456-7890',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4A3022).withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A3022),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    lang.tr('Tutup'),
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.tr('Bahasa'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 16),
              _buildLanguageOption('Bahasa Indonesia', '🇮🇩', false),
              const SizedBox(height: 8),
              _buildLanguageOption('English', '🇬🇧', true),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String name, String flag, bool isEnglishOption) {
    final lang = Provider.of<LanguageProvider>(context);
    final isSelected = lang.isEnglish == isEnglishOption;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        lang.toggleLanguage(isEnglishOption);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.isEnglish
                  ? 'Language changed to $name'
                  : 'Bahasa diubah ke $name',
            ),
            backgroundColor: const Color(0xFF4A3022),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A3022)
                : const Color(0xFFD2B48C),
          ),
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? const Color(0xFF4A3022).withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF4A3022),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4A3022),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F3),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5D3A1A)),
            )
          : _user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.tr('Gagal memuat profil.'),
                    style: GoogleFonts.inter(color: const Color(0xFF4A3022)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetchProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A3022),
                    ),
                    child: Text(
                      lang.tr('Coba Lagi'),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildProfileHero(lang)),

                // Menu Options
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account Section
                        Text(
                          lang.tr('AKUN'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF8B7355),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuCard([
                          _buildMenuItem(
                            icon: Icons.person_outline,
                            label: lang.tr('Informasi Pribadi'),
                            subtitle: _user!.email,
                            onTap: () => _showInfoSheet(),
                          ),
                          _buildMenuItem(
                            icon: Icons.phone_outlined,
                            label: lang.tr('Nomor Telepon'),
                            subtitle: _user!.phone ?? lang.tr('Belum diatur'),
                            onTap: () => _showInfoSheet(),
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // Preferences Section
                        Text(
                          lang.tr('PREFERENSI'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF8B7355),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuCard([
                          _buildMenuItemSwitch(
                            icon: Icons.notifications_outlined,
                            label: lang.tr('Notifikasi'),
                            subtitle: _notificationsEnabled
                                ? lang.tr('Aktif')
                                : lang.tr('Nonaktif'),
                            value: _notificationsEnabled,
                            onChanged: _toggleNotification,
                          ),
                          _buildMenuItem(
                            icon: Icons.language,
                            label: lang.tr('Bahasa'),
                            subtitle: lang.isEnglish
                                ? 'English'
                                : 'Bahasa Indonesia',
                            onTap: _showLanguageSheet,
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // Info Section
                        Text(
                          lang.tr('LAINNYA'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF8B7355),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuCard([
                          _buildMenuItem(
                            icon: Icons.info_outline,
                            label: lang.tr('Tentang Aplikasi'),
                            subtitle: lang.tr('Versi 1.0.0'),
                            onTap: _showAboutDialog,
                          ),
                          _buildMenuItem(
                            icon: Icons.privacy_tip_outlined,
                            label: lang.tr('Kebijakan Privasi'),
                            onTap: _showPrivacyPolicyDialog,
                          ),
                          _buildMenuItem(
                            icon: Icons.help_outline,
                            label: lang.tr('Bantuan'),
                            onTap: _showHelpDialog,
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, size: 18),
                            label: Text(
                              lang.tr('Keluar dari Akun'),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF4F1),
                              foregroundColor: const Color(0xFFD75A4A),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                  color: Color(0xFFF1CBC5),
                                ),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHero(LanguageProvider lang) {
    final user = _user!;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5D3A1A), Color(0xFF8B6B4A), Color(0xFFD4A574)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D3A1A).withValues(alpha: 0.25),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -26,
                top: -34,
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                right: 52,
                bottom: -48,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.tr('Profil'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.coffee_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFFFFF8F0),
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.inter(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF5D3A1A),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    user.role.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECDDD1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D3A1A).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 16,
                  color: const Color(0xFFECDDD1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0DFD0)),
              ),
              child: Icon(icon, color: const Color(0xFF5D3A1A), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFF8B7355),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF9F3ED),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Color(0xFF8B7355),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemSwitch({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0DFD0)),
            ),
            child: Icon(icon, color: const Color(0xFF5D3A1A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF8B7355),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF5D3A1A),
            activeTrackColor: const Color(0xFFD4A574),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet() {
    if (_user == null) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.tr('Informasi Pribadi'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.person_outline, lang.tr('Nama'), _user!.name),
              const SizedBox(height: 14),
              _buildInfoRow(Icons.email_outlined, 'Email', _user!.email),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.phone_outlined,
                lang.tr('Telepon'),
                _user!.phone ?? lang.tr('Belum diatur'),
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.badge_outlined,
                lang.tr('Peran'),
                _user!.role.toUpperCase(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E6D3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF4A3022)),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3022),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
