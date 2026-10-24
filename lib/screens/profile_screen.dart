import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/brand_mark.dart';
import '../widgets/coffee_overlays.dart';
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
  bool _isLoggingOut = false;
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
    final isEnabled = await PushNotificationService.instance.setEnabled(value);
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = value ? isEnabled : false;
    });

    if (value && !isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Izin notifikasi belum aktif. Periksa pengaturan aplikasi di perangkat.',
          ),
        ),
      );
    }
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

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    final lang = context.read<LanguageProvider>();
    _isLoggingOut = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => CoffeeDialog(
          title: lang.isEnglish ? 'Take a little break?' : 'Keluar dari akun?',
          message: lang.tr('Apakah kamu yakin ingin keluar dari akun ini?'),
          icon: Icons.logout_rounded,
          accent: CoffeeColors.danger,
          dismissLabel: lang.tr('Tutup'),
          actions: [
            CoffeeButton(
              label: lang.tr('Keluar'),
              destructive: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            CoffeeButton(
              label: lang.tr('Batal'),
              secondary: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final deviceToken = await PushNotificationService.instance.currentToken();
      await _apiService.logout(deviceToken: deviceToken);
      await PushNotificationService.instance.onLoggedOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } finally {
      _isLoggingOut = false;
    }
  }

  void _showAboutDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => CoffeeDialog(
        title: 'Ciks Coffee',
        message: lang.tr(
          'Aplikasi pemesanan kopi Ciks Coffee.\nNikmati kopi favoritmu dengan mudah!',
        ),
        content: Text(
          lang.tr('Versi 1.0.0'),
          style: const TextStyle(
            fontFamily: 'CiksSans',
            color: CoffeeColors.muted,
            fontSize: 12,
          ),
        ),
        dismissLabel: lang.tr('Tutup'),
        actions: [
          CoffeeButton(
            label: lang.tr('Tutup'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => CoffeeDialog(
        title: lang.tr('Kebijakan Privasi'),
        icon: Icons.privacy_tip_outlined,
        message: lang.isEnglish
            ? 'Your privacy is important to us. We collect your data only for order processing and improving service quality. We do not share your data with third parties without your explicit consent.'
            : 'Privasi Anda penting bagi kami. Kami mengumpulkan data Anda hanya untuk keperluan pemrosesan pesanan dan peningkatan layanan. Kami tidak membagikan data Anda kepada pihak ketiga tanpa izin Anda.',
        dismissLabel: lang.tr('Tutup'),
        actions: [
          CoffeeButton(
            label: lang.tr('Tutup'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => CoffeeDialog(
        title: lang.tr('Bantuan'),
        icon: Icons.support_agent_rounded,
        message: lang.isEnglish
            ? 'Need help with your order or the application? Contact our customer support team.\n\nEmail: support@cikscoffee.com\nPhone: +62 812-3456-7890'
            : 'Butuh bantuan terkait pesanan atau penggunaan aplikasi? Hubungi tim layanan pelanggan kami.\n\nEmail: support@cikscoffee.com\nTelepon: +62 812-3456-7890',
        dismissLabel: lang.tr('Tutup'),
        actions: [
          CoffeeButton(
            label: lang.tr('Tutup'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet() {
    final lang = context.read<LanguageProvider>();
    showCoffeeSheet<void>(
      context: context,
      builder: (_) => CoffeeSheet(
        title: lang.isEnglish ? 'Choose language' : 'Pilih Bahasa',
        dismissLabel: lang.tr('Tutup'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('Bahasa Indonesia', '🇮🇩', false),
            const SizedBox(height: 12),
            _buildLanguageOption('English', '🇬🇧', true),
          ],
        ),
      ),
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
                        SizedBox(height: 24),
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
          clipBehavior: Clip.antiAlias,
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
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -25,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                right: 35,
                bottom: -45,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
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
                          child: const BrandMark(
                            size: 26,
                            color: BrandMark.cream,
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
                                      lang.tr(user.role.toUpperCase()),
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
    final lang = context.read<LanguageProvider>();
    showCoffeeSheet<void>(
      context: context,
      builder: (_) => CoffeeSheet(
        title: lang.tr('Informasi Pribadi'),
        dismissLabel: lang.tr('Tutup'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow(Icons.person_outline, lang.tr('Nama'), _user!.name),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.email_outlined, 'Email', _user!.email),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.phone_outlined,
              lang.tr('Telepon'),
              _user!.phone ?? lang.tr('Belum diatur'),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.badge_outlined,
              lang.tr('Peran'),
              lang.tr(_user!.role.toUpperCase()),
            ),
          ],
        ),
      ),
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
