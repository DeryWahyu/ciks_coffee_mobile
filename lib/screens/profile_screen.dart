import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),
        ),
        content: Text(
          lang.tr('Apakah kamu yakin ingin keluar dari akun ini?'),
          style: GoogleFonts.inter(color: const Color(0xFF4A3022)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(lang.tr('Batal'), style: GoogleFonts.inter(color: Colors.grey)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(lang.tr('Keluar'), style: GoogleFonts.inter(color: Colors.white)),
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
                child: const Icon(Icons.coffee, color: Color(0xFF4A3022), size: 40),
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
                lang.tr('Aplikasi pemesanan kopi Ciks Coffee.\nNikmati kopi favoritmu dengan mudah!'),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(lang.tr('Tutup'), style: GoogleFonts.inter(color: Colors.white)),
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
            content: Text(lang.isEnglish ? 'Language changed to $name' : 'Bahasa diubah ke $name'),
            backgroundColor: const Color(0xFF4A3022),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF4A3022) : const Color(0xFFD2B48C),
          ),
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? const Color(0xFF4A3022).withValues(alpha: 0.05) : null,
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
              const Icon(Icons.check_circle, color: Color(0xFF4A3022), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A3022)))
          : _user == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(lang.tr('Gagal memuat profil.'), style: GoogleFonts.inter(color: const Color(0xFF4A3022))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3022)),
                        child: Text(lang.tr('Coba Lagi'), style: GoogleFonts.inter(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // Profile Header
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4A3022),
                              const Color(0xFF4A3022).withValues(alpha: 0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                        ),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                child: Text(
                                  _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _user!.name,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _user!.email,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _user!.role.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: const Color(0xFF4A3022).withValues(alpha: 0.4),
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
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: const Color(0xFF4A3022).withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildMenuCard([
                              _buildMenuItemSwitch(
                                icon: Icons.notifications_outlined,
                                label: lang.tr('Notifikasi'),
                                subtitle: _notificationsEnabled ? lang.tr('Aktif') : lang.tr('Nonaktif'),
                                value: _notificationsEnabled,
                                onChanged: (v) => setState(() => _notificationsEnabled = v),
                              ),
                              _buildMenuItem(
                                icon: Icons.language,
                                label: lang.tr('Bahasa'),
                                subtitle: lang.isEnglish ? 'English' : 'Bahasa Indonesia',
                                onTap: _showLanguageSheet,
                              ),
                            ]),
                            const SizedBox(height: 24),

                            // Info Section
                            Text(
                              lang.tr('LAINNYA'),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: const Color(0xFF4A3022).withValues(alpha: 0.4),
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
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(lang.tr('Halaman kebijakan privasi')),
                                      backgroundColor: const Color(0xFF4A3022),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuItem(
                                icon: Icons.help_outline,
                                label: lang.tr('Bantuan'),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(lang.tr('Hubungi kami di support@cikscoffee.com')),
                                      backgroundColor: const Color(0xFF4A3022),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
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
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: Colors.red.shade200),
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

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                Divider(height: 1, indent: 56, color: const Color(0xFFD2B48C).withValues(alpha: 0.2)),
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6D3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF4A3022), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A3022),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: const Color(0xFF4A3022).withValues(alpha: 0.3)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E6D3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4A3022), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4A3022),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF4A3022).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4A3022),
            activeTrackColor: const Color(0xFFD2B48C),
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
              _buildInfoRow(Icons.phone_outlined, lang.tr('Telepon'), _user!.phone ?? lang.tr('Belum diatur')),
              const SizedBox(height: 14),
              _buildInfoRow(Icons.badge_outlined, lang.tr('Peran'), _user!.role.toUpperCase()),
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
