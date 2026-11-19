import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/app_info_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_message.dart';
import '../widgets/brand_mark.dart';
import '../widgets/coffee_overlays.dart';
import '../widgets/navigation_safe_content.dart';
import '../widgets/profile_forms.dart';
import '../providers/language_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.apiService,
    this.notificationService,
    this.appInfoService,
  });
  final ApiService? apiService;
  final PushNotificationService? notificationService;
  final AppInfoService? appInfoService;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  late final AppInfoService _appInfo =
      widget.appInfoService ?? AppInfoService();
  PushNotificationService get _push =>
      widget.notificationService ?? PushNotificationService.instance;
  UserModel? _user;
  String? _profileError, _appVersion;
  bool _isLoading = true,
      _isLoggingOut = false,
      _logoutPromptOpen = false,
      _notificationBusy = true,
      _notificationsEnabled = false;
  NotificationActivation? _notificationState;
  int _profileRequest = 0, _notificationRequest = 0;
  final _notificationTimers = <Timer>{};
  final _notificationWaiters = <Completer<NotificationActivation>>{};
  String _t(String id, String en) =>
      context.read<LanguageProvider>().isEnglish ? en : id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_fetchProfile());
    unawaited(_loadNotificationStatus());
    unawaited(_loadVersion());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _notificationTimers) {
      timer.cancel();
    }
    for (final waiter in _notificationWaiters.toList()) {
      if (!waiter.isCompleted) {
        waiter.complete(
          const NotificationActivation(
            NotificationActivationStatus.serverUnavailable,
          ),
        );
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_notificationBusy &&
        !_isLoggingOut) {
      unawaited(_loadNotificationStatus());
    }
  }

  Future<void> _loadVersion() async {
    final version = await _appInfo.version();
    if (mounted) setState(() => _appVersion = version);
  }

  Future<NotificationActivation> _waitForNotification(
    Future<NotificationActivation> request,
  ) {
    final result = Completer<NotificationActivation>();
    final timer = Timer(const Duration(seconds: 12), () {
      if (!result.isCompleted) {
        result.complete(
          const NotificationActivation(
            NotificationActivationStatus.serverUnavailable,
          ),
        );
      }
    });
    _notificationTimers.add(timer);
    _notificationWaiters.add(result);
    request.then<void>(
      (value) {
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) {
          result.complete(
            const NotificationActivation(
              NotificationActivationStatus.serverUnavailable,
            ),
          );
        }
      },
    );
    return result.future.whenComplete(() {
      timer.cancel();
      _notificationTimers.remove(timer);
      _notificationWaiters.remove(result);
    });
  }

  Future<void> _loadNotificationStatus() async {
    final request = ++_notificationRequest;
    if (mounted) setState(() => _notificationBusy = true);
    NotificationActivation result;
    try {
      result = await _waitForNotification(_push.getStatus());
    } catch (_) {
      result = const NotificationActivation(
        NotificationActivationStatus.serverUnavailable,
      );
    }
    if (!mounted || request != _notificationRequest) return;
    setState(() {
      _notificationBusy = false;
      _notificationState = result;
      _notificationsEnabled = result.enabled;
    });
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleNotification(bool value) async {
    if (_notificationBusy || _isLoggingOut) return;
    _notificationRequest++;
    setState(() => _notificationBusy = true);
    NotificationActivation result;
    try {
      result = await _waitForNotification(_push.setEnabled(value));
    } catch (_) {
      result = const NotificationActivation(
        NotificationActivationStatus.serverUnavailable,
      );
    }
    if (!mounted) return;
    final success = value
        ? result.enabled
        : result.status == NotificationActivationStatus.disabled;
    setState(() {
      _notificationBusy = false;
      _notificationState = result;
      if (success) _notificationsEnabled = value;
    });
    if (!success) _message(result.message);
  }

  Future<void> _openNotificationSettings() async {
    final opened = await _appInfo.openNotificationSettings();
    if (mounted && !opened) {
      _message(
        _t(
          'Pengaturan belum dapat dibuka. Buka pengaturan notifikasi Ciks Coffee melalui pengaturan perangkat.',
          'Open your device settings and choose Ciks Coffee notifications.',
        ),
      );
    }
  }

  Future<void> _fetchProfile() async {
    final request = ++_profileRequest;
    if (_user == null) {
      setState(() {
        _isLoading = true;
        _profileError = null;
      });
    }
    Map<String, dynamic> result;
    try {
      result = await _apiService.getProfile();
    } catch (_) {
      result = {
        'success': false,
        'message': 'Profil belum dapat dimuat. Periksa koneksi lalu coba lagi.',
      };
    }
    if (!mounted || request != _profileRequest) return;
    UserModel? user;
    if (result['success'] == true) {
      try {
        user = UserModel.fromJson(Map<String, dynamic>.from(result['data']));
      } catch (_) {
        result = {
          'success': false,
          'message': 'Data profil tidak lengkap. Silakan coba lagi.',
        };
      }
    }
    setState(() {
      _isLoading = false;
      if (user != null) {
        _user = user;
        _profileError = null;
      } else {
        _profileError = UserMessage.display(
          result['message'],
          fallback: 'Gagal memuat profil.',
        );
      }
    });
    if (user == null && _user != null) _message(_profileError!);
  }

  Future<void> _editProfile() async {
    if (_user == null || _isLoggingOut) return;
    final user = await showCoffeeSheet<UserModel>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ProfileFormSheet(api: _apiService, user: _user),
    );
    if (!mounted || user == null) return;
    _profileRequest++;
    setState(() {
      _user = user;
      _profileError = null;
      _isLoading = false;
    });
    _message(_t('Profil berhasil diperbarui.', 'Profile updated.'));
  }

  Future<void> _changePassword() async {
    if (_isLoggingOut) return;
    final changed = await showCoffeeSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ProfileFormSheet(
        api: _apiService,
        deviceToken: _currentDeviceToken(),
      ),
    );
    if (mounted && changed == true) {
      try {
        _push.invalidateRegistration();
      } catch (_) {}
      unawaited(_loadNotificationStatus());
      _message(
        _t(
          'Kata sandi berhasil diperbarui. Sesi di perangkat lain telah diakhiri.',
          'Password changed. Other devices have been signed out.',
        ),
      );
    }
  }

  String? _currentDeviceToken() {
    try {
      return _push.registeredToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut || _logoutPromptOpen) return;
    _logoutPromptOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => CoffeeDialog(
          title: _t('Keluar dari akun?', 'Log out?'),
          message: _t(
            'Apakah kamu yakin ingin keluar dari akun ini?',
            'Are you sure you want to log out?',
          ),
          icon: Icons.logout_rounded,
          accent: CoffeeColors.danger,
          dismissLabel: _t('Tutup', 'Close'),
          actions: [
            CoffeeButton(
              label: _t('Keluar', 'Log out'),
              destructive: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            CoffeeButton(
              label: _t('Batal', 'Cancel'),
              secondary: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _isLoggingOut = true);
      String? token;
      try {
        token = await _push.currentToken().timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Logout still works if notification services are unavailable. */
      }
      await _apiService.logout(deviceToken: token);
      try {
        await _push.onLoggedOut().timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Local account credentials have already been cleared. */
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        _message(
          _t(
            'Belum dapat keluar dari akun. Silakan coba lagi.',
            'Could not log out. Please try again.',
          ),
        );
      }
    } finally {
      _logoutPromptOpen = false;
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => CoffeeDialog(
        title: 'Ciks Coffee',
        message: _t(
          'Aplikasi pemesanan Ciks Coffee dengan pembayaran QRIS dan pemantauan status pesanan.',
          'Ciks Coffee ordering app with QRIS payments and order tracking.',
        ),
        content: Text(
          _appVersion == null
              ? _t(
                  'Informasi versi belum tersedia.',
                  'Version information is unavailable.',
                )
              : '${_t('Versi', 'Version')} $_appVersion',
          style: const TextStyle(
            fontFamily: 'CiksSans',
            color: CoffeeColors.muted,
          ),
        ),
        dismissLabel: _t('Tutup', 'Close'),
        actions: [
          CoffeeButton(
            label: _t('Tutup', 'Close'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showCoffeeSheet<void>(
      context: context,
      builder: (_) => CoffeeSheet(
        title: _t('Kebijakan Privasi', 'Privacy Policy'),
        dismissLabel: _t('Tutup', 'Close'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBlock(
              _t('Data akun', 'Account data'),
              _t(
                'Nama, email, dan nomor telepon digunakan untuk akun dan identitas pelanggan pada pemesanan.',
                'Your name, email, and phone number are used for your account and ordering identity.',
              ),
            ),
            _infoBlock(
              _t('Pesanan dan bukti pembayaran', 'Orders and payment proof'),
              _t(
                'Pesanan disimpan pada sistem Ciks Coffee. Bukti pembayaran QRIS diperiksa oleh karyawan sebelum pesanan diproses.',
                'Orders are stored in the Ciks Coffee system. Staff review QRIS payment proof before processing orders.',
              ),
            ),
            _infoBlock(
              _t('Notifikasi perangkat', 'Device notifications'),
              _t(
                'Identitas notifikasi perangkat didaftarkan untuk mengirim pembaruan pesanan melalui Firebase. Notifikasi dapat dinonaktifkan di menu profil atau pengaturan perangkat.',
                'A device notification identifier is registered to send order updates through Firebase. You can turn notifications off in your profile or device settings.',
              ),
            ),
            _infoBlock(
              _t('Mengelola akun', 'Manage your account'),
              _t(
                'Anda dapat mengubah profil, mengganti kata sandi, dan keluar dari akun. Untuk bantuan terkait data akun atau pesanan, temui kasir Ciks Coffee.',
                'You can update your profile, change your password, and log out. Ask the Ciks Coffee cashier for help with account or order data.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBlock(String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontWeight: FontWeight.w700,
            color: CoffeeColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'CiksSans',
            height: 1.6,
            color: CoffeeColors.muted,
          ),
        ),
      ],
    ),
  );

  void _showHelpDialog() {
    final questions = [
      (
        _t('Bagaimana cara memesan?', 'How do I order?'),
        _t(
          'Pilih menu di Beranda, masukkan ke keranjang, lalu lanjutkan pembayaran menggunakan QRIS.',
          'Choose items on Home, add them to your cart, then continue with QRIS payment.',
        ),
      ),
      (
        _t('Mengapa perlu bukti pembayaran?', 'Why is payment proof required?'),
        _t(
          'Unggah bukti setelah membayar QRIS. Karyawan memeriksa bukti sebelum pesanan masuk ke antrean.',
          'Upload proof after paying with QRIS. Staff verify it before the order enters the queue.',
        ),
      ),
      (
        _t(
          'Sudah membayar tetapi muncul kendala?',
          'Already paid but something went wrong?',
        ),
        _t(
          'Jangan membayar ulang. Periksa menu Status dan sesi pembayaran di Keranjang. Tunjukkan nomor pesanan serta bukti kepada kasir jika perlu bantuan.',
          'Do not pay again. Check Status and the payment session in Cart. Show the order number and proof to the cashier if you need help.',
        ),
      ),
      (
        _t('Bagaimana mengambil pesanan?', 'How do I collect my order?'),
        _t(
          'Pantau menu Status. Saat pesanan siap, ambil di kasir lalu konfirmasikan bahwa pesanan sudah diambil melalui aplikasi.',
          'Track your order in Status. When it is ready, collect it from the cashier and confirm pickup in the app.',
        ),
      ),
      (
        _t(
          'Tidak bisa masuk atau perlu bantuan lain?',
          'Cannot log in or need more help?',
        ),
        _t(
          'Temui kasir Ciks Coffee. Sampaikan masalah dan nomor pesanan jika terkait transaksi.',
          'Ask the Ciks Coffee cashier. Describe the issue and provide your order number for transaction questions.',
        ),
      ),
    ];
    showCoffeeSheet<void>(
      context: context,
      builder: (_) => CoffeeSheet(
        title: _t('Bantuan', 'Help'),
        dismissLabel: _t('Tutup', 'Close'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in questions)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  item.$1,
                  style: const TextStyle(
                    fontFamily: 'CiksSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        fontFamily: 'CiksSans',
                        color: CoffeeColors.muted,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    final lang = context.read<LanguageProvider>();
    showCoffeeSheet<void>(
      context: context,
      builder: (_) => CoffeeSheet(
        title: _t('Pilih Bahasa', 'Choose language'),
        dismissLabel: _t('Tutup', 'Close'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              (false, 'Bahasa Indonesia'),
              (true, 'English'),
            ])
              ListTile(
                selectedColor: CoffeeColors.ink,
                selectedTileColor: CoffeeColors.cream,
                title: Text(option.$2),
                selected: lang.isEnglish == option.$1,
                leading: Icon(
                  lang.isEnglish == option.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final saved = await lang.toggleLanguage(option.$1);
                  if (mounted) {
                    _message(
                      saved
                          ? _t(
                              'Bahasa berhasil diperbarui.',
                              'Language updated.',
                            )
                          : _t(
                              'Bahasa belum dapat disimpan. Silakan coba lagi.',
                              'Language could not be saved. Please try again.',
                            ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: const Color(0xFF8B7355),
          ),
        ),
        const SizedBox(height: 10),
        _buildMenuCard(children),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F3),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: CoffeeColors.ink),
            )
          : _user == null
          ? NavigationSafeContent(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: CoffeeColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.tr(_profileError ?? 'Gagal memuat profil.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      color: CoffeeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CoffeeButton(
                    label: lang.tr('Coba Lagi'),
                    onPressed: _fetchProfile,
                  ),
                  const SizedBox(height: 10),
                  CoffeeButton(
                    key: const ValueKey('profile-logout'),
                    label: lang.tr('Keluar dari Akun'),
                    secondary: true,
                    loading: _isLoggingOut,
                    onPressed: _logout,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchProfile,
              color: CoffeeColors.ink,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildProfileHero(lang)),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList.list(
                      children: [
                        _section(lang.tr('AKUN'), [
                          _buildMenuItem(
                            icon: Icons.edit_outlined,
                            label: _t('Edit profil', 'Edit profile'),
                            subtitle: _t(
                              'Nama, email, dan nomor telepon',
                              'Name, email, and phone number',
                            ),
                            onTap: _editProfile,
                          ),
                          _buildMenuItem(
                            icon: Icons.lock_outline,
                            label: _t('Ubah kata sandi', 'Change password'),
                            subtitle: _t(
                              'Amankan akses akun',
                              'Secure your account',
                            ),
                            onTap: _changePassword,
                          ),
                        ]),
                        _section(lang.tr('PREFERENSI'), [
                          _buildMenuItemSwitch(
                            icon: Icons.notifications_outlined,
                            label: lang.tr('Notifikasi'),
                            subtitle: _notificationBusy
                                ? _t(
                                    'Memeriksa notifikasi?',
                                    'Checking notifications?',
                                  )
                                : _notificationState?.status ==
                                      NotificationActivationStatus
                                          .serverUnavailable
                                ? _t('Belum tersambung', 'Not connected')
                                : _notificationsEnabled
                                ? lang.tr('Aktif')
                                : lang.tr('Nonaktif'),
                            value: _notificationsEnabled,
                            onChanged: _notificationBusy || _isLoggingOut
                                ? null
                                : _toggleNotification,
                          ),
                          if (_notificationState?.status ==
                              NotificationActivationStatus.permissionDenied)
                            TextButton.icon(
                              onPressed: _openNotificationSettings,
                              icon: const Icon(Icons.settings_outlined),
                              label: Text(
                                _t(
                                  'Buka pengaturan notifikasi',
                                  'Open notification settings',
                                ),
                              ),
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
                        _section(lang.tr('LAINNYA'), [
                          _buildMenuItem(
                            icon: Icons.help_outline,
                            label: lang.tr('Bantuan'),
                            subtitle: _t(
                              'Panduan pemesanan dan QRIS',
                              'Ordering and QRIS guide',
                            ),
                            onTap: _showHelpDialog,
                          ),
                          _buildMenuItem(
                            icon: Icons.privacy_tip_outlined,
                            label: lang.tr('Kebijakan Privasi'),
                            onTap: _showPrivacyPolicyDialog,
                          ),
                          _buildMenuItem(
                            icon: Icons.info_outline,
                            label: lang.tr('Tentang Aplikasi'),
                            subtitle: _appVersion == null
                                ? _t('Informasi aplikasi', 'App information')
                                : '${_t('Versi', 'Version')} $_appVersion',
                            onTap: _showAboutDialog,
                          ),
                        ]),
                        CoffeeButton(
                          key: const ValueKey('profile-logout'),
                          label: lang.tr('Keluar dari Akun'),
                          icon: Icons.logout_rounded,
                          destructive: true,
                          loading: _isLoggingOut,
                          onPressed: _logout,
                        ),
                        SizedBox(
                          height: 24 + MediaQuery.paddingOf(context).bottom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                        Expanded(
                          child: Text(
                            lang.tr('Profil'),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
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
                              user.name.trim().isNotEmpty
                                  ? user.name
                                        .trim()
                                        .characters
                                        .first
                                        .toUpperCase()
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
                                    Flexible(
                                      child: Text(
                                        lang.tr(user.role.toUpperCase()),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.9,
                                        ),
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
    required ValueChanged<bool>? onChanged,
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
}
