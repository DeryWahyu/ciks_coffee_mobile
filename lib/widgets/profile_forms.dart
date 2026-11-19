import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../services/user_message.dart';
import 'coffee_overlays.dart';

class ProfileFormSheet extends StatefulWidget {
  const ProfileFormSheet({
    super.key,
    required this.api,
    this.user,
    this.deviceToken,
  });
  final ApiService api;

  /// A missing user selects the password form instead of the profile form.
  final UserModel? user;
  final String? deviceToken;

  @override
  State<ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<ProfileFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _phone = TextEditingController(text: widget.user?.phone);
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _visible = <String>{};
  final _errors = <String, String>{};
  bool _saving = false;
  String? _error;
  bool get _editing => widget.user != null;
  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != widget.user?.email.toLowerCase();
  String _t(String id, String en) =>
      context.read<LanguageProvider>().isEnglish ? en : id;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _current,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    _errors.clear();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    Map<String, dynamic> result;
    try {
      result = _editing
          ? await widget.api.updateProfile(
              name: _name.text,
              email: _email.text,
              phone: _phone.text,
              currentPassword: _emailChanged ? _current.text : null,
            )
          : await widget.api.changePassword(
              currentPassword: _current.text,
              password: _password.text,
              confirmation: _confirmation.text,
              deviceToken: widget.deviceToken,
            );
    } catch (_) {
      result = {
        'success': false,
        'message': 'Data belum dapat disimpan. Periksa koneksi lalu coba lagi.',
      };
    }
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.of(context).pop(_editing ? result['user'] : true);
      return;
    }
    setState(() {
      _saving = false;
      _error = UserMessage.display(result['message']);
      final errors = result['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final values = entry.value;
          if (values is List && values.isNotEmpty) {
            _errors[entry.key.toString()] = UserMessage.display(
              values.first,
              fallback: _error!,
            );
          }
        }
      }
    });
    _form.currentState!.validate();
  }

  Widget _field(
    String name,
    TextEditingController controller,
    String label, {
    bool secret = false,
    String? helper,
    TextInputType? keyboard,
    String? Function(String)? validate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('profile-field-$name'),
        controller: controller,
        enabled: !_saving,
        obscureText: secret && !_visible.contains(name),
        autocorrect: false,
        enableSuggestions: !secret,
        keyboardType: keyboard,
        maxLength: name == 'phone'
            ? 24
            : secret
            ? 128
            : 255,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {
          _errors.remove(name);
          _error = null;
        }),
        validator: (value) => _errors[name] ?? validate?.call(value ?? ''),
        style: const TextStyle(fontFamily: 'CiksSans', color: CoffeeColors.ink),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          errorMaxLines: 3,
          counterText: '',
          filled: true,
          fillColor: CoffeeColors.cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CoffeeColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CoffeeColors.border),
          ),
          suffixIcon: secret
              ? IconButton(
                  tooltip: _visible.contains(name)
                      ? _t('Sembunyikan kata sandi', 'Hide password')
                      : _t('Tampilkan kata sandi', 'Show password'),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _visible.contains(name)
                              ? _visible.remove(name)
                              : _visible.add(name);
                        }),
                  icon: Icon(
                    _visible.contains(name)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return PopScope(
      canPop: !_saving,
      child: CoffeeSheet(
        title: _editing
            ? _t('Edit profil', 'Edit profile')
            : _t('Ubah kata sandi', 'Change password'),
        dismissLabel: _t('Tutup', 'Close'),
        canDismiss: !_saving,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _editing
                      ? _t(
                          'Perbarui data akun yang digunakan untuk pemesanan.',
                          'Update your account details for ordering.',
                        )
                      : _t(
                          'Gunakan kata sandi baru minimal 8 karakter. Perangkat lain akan diminta masuk kembali.',
                          'Use at least 8 characters. Other devices will be signed out.',
                        ),
                  style: const TextStyle(
                    fontFamily: 'CiksSans',
                    fontSize: 13,
                    height: 1.5,
                    color: CoffeeColors.muted,
                  ),
                ),
              ),
              if (_editing) ...[
                _field(
                  'name',
                  _name,
                  _t('Nama', 'Name'),
                  validate: (v) => v.trim().isEmpty
                      ? _t('Nama wajib diisi.', 'Name is required.')
                      : null,
                ),
                _field(
                  'email',
                  _email,
                  'Email',
                  keyboard: TextInputType.emailAddress,
                  validate: (v) =>
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                      ? _t(
                          'Masukkan alamat email yang valid.',
                          'Enter a valid email address.',
                        )
                      : null,
                ),
                _field(
                  'phone',
                  _phone,
                  _t('Nomor telepon', 'Phone number'),
                  keyboard: TextInputType.phone,
                  helper: _t(
                    'Opsional, 8–15 digit. Contoh: 081234567890.',
                    'Optional, 8–15 digits. Example: +6281234567890.',
                  ),
                  validate: (v) =>
                      v.trim().isNotEmpty &&
                          !RegExp(
                            r'^\+?[0-9]{8,15}$',
                          ).hasMatch(v.replaceAll(RegExp(r'[\s().-]'), ''))
                      ? _t(
                          'Nomor telepon belum sesuai.',
                          'Enter a valid phone number.',
                        )
                      : null,
                ),
              ],
              if (!_editing || _emailChanged)
                _field(
                  'current_password',
                  _current,
                  _t('Kata sandi saat ini', 'Current password'),
                  secret: true,
                  helper: _editing
                      ? _t(
                          'Email baru digunakan untuk masuk berikutnya. Masukkan kata sandi untuk mengubah email.',
                          'The new email will be used for your next login. Confirm your password to change it.',
                        )
                      : null,
                  validate: (v) => v.isEmpty
                      ? _t(
                          'Kata sandi saat ini wajib diisi.',
                          'Current password is required.',
                        )
                      : null,
                ),
              if (!_editing) ...[
                _field(
                  'password',
                  _password,
                  _t('Kata sandi baru', 'New password'),
                  secret: true,
                  validate: (v) {
                    if (v.trim().isEmpty || v.length < 8) {
                      return _t(
                        'Kata sandi baru minimal 8 karakter.',
                        'Use at least 8 characters.',
                      );
                    }
                    if (v == _current.text) {
                      return _t(
                        'Kata sandi baru harus berbeda.',
                        'Choose a different password.',
                      );
                    }
                    return null;
                  },
                ),
                _field(
                  'password_confirmation',
                  _confirmation,
                  _t('Konfirmasi kata sandi baru', 'Confirm new password'),
                  secret: true,
                  validate: (v) => v != _password.text || v.isEmpty
                      ? _t(
                          'Konfirmasi kata sandi tidak cocok.',
                          'Passwords do not match.',
                        )
                      : null,
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    key: const ValueKey('profile-form-error'),
                    style: const TextStyle(
                      color: CoffeeColors.danger,
                      fontFamily: 'CiksSans',
                    ),
                  ),
                ),
              CoffeeButton(
                label: _t('Simpan perubahan', 'Save changes'),
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 10),
              CoffeeButton(
                label: _t('Batal', 'Cancel'),
                secondary: true,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
