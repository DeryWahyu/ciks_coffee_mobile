/// Messages from older servers must remain readable without exposing diagnostics.
class UserMessage {
  static String display(
    Object? value, {
    String fallback = 'Permintaan belum dapat diproses. Silakan coba lagi.',
  }) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) return fallback;
    if (RegExp(r'^Unauthenticated\.?$', caseSensitive: false).hasMatch(text)) {
      return forStatus(401);
    }
    if (RegExp(r'^Unauthorized\.?$', caseSensitive: false).hasMatch(text)) {
      return forStatus(403);
    }
    if (RegExp(
      r'Too Many (Attempts|Requests)',
      caseSensitive: false,
    ).hasMatch(text)) {
      return forStatus(429);
    }
    if (RegExp(
      r'CSRF token mismatch|Page Expired',
      caseSensitive: false,
    ).hasMatch(text)) {
      return forStatus(419);
    }
    if (RegExp(
      r'validation\.|SQLSTATE|No query results|App\\Models\\|<[^>]+>|Exception|stack trace|Unexpected token|is not valid JSON|^The .+ field |^The .+ has already been taken\.|^(Forbidden|Not Found|Server Error|Service Unavailable|Bad Request)\.?$',
      caseSensitive: false,
    ).hasMatch(text)) {
      return fallback;
    }
    // Business messages are not restricted to a vocabulary: keep their reason intact.
    return text;
  }

  static String fromResponse(Map<String, dynamic> data, int status) {
    final errors = data['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final values = entry.value;
        final candidate = values is List && values.isNotEmpty
            ? values.first
            : values;
        if (candidate is! String || candidate.isEmpty) continue;
        if (candidate.startsWith('validation.')) {
          return _validation(candidate, entry.key.toString());
        }
        return display(candidate, fallback: forStatus(status));
      }
    }
    return display(data['message'], fallback: forStatus(status));
  }

  static String _validation(String rule, String field) {
    final label = switch (field) {
      'email' => 'Email',
      'phone' => 'Nomor telepon',
      'password' => 'Kata sandi',
      'name' => 'Nama',
      'payment_proof' => 'Bukti pembayaran',
      _ => 'Isian ini',
    };
    if (rule == 'validation.unique') {
      return field == 'email'
          ? 'Email sudah terdaftar. Gunakan email lain atau masuk ke akun Anda.'
          : '$label sudah digunakan. Gunakan nilai lain.';
    }
    if (rule.startsWith('validation.required')) return '$label wajib diisi.';
    return switch (rule) {
      'validation.email' =>
        'Masukkan alamat email yang valid. Contoh: nama@email.com.',
      'validation.confirmed' => 'Konfirmasi kata sandi tidak cocok.',
      'validation.max.string' =>
        '$label terlalu panjang. Periksa kembali batas isian.',
      'validation.min.string' =>
        '$label terlalu pendek. Periksa kembali batas isian.',
      'validation.image' || 'validation.mimes' || 'validation.mimetypes' =>
        'Format gambar tidak didukung. Gunakan JPG, PNG, atau WebP.',
      'validation.max.file' =>
        'Ukuran gambar terlalu besar. Pilih gambar yang lebih kecil.',
      _ => '$label belum sesuai. Periksa kembali data yang diisi.',
    };
  }

  static String forStatus(int status) => switch (status) {
    401 ||
    419 => 'Sesi Anda telah berakhir. Silakan masuk kembali untuk melanjutkan.',
    403 => 'Anda tidak memiliki izin untuk melakukan tindakan ini.',
    404 =>
      'Data yang diminta tidak ditemukan. Muat ulang lalu periksa kembali.',
    409 => 'Data telah berubah. Periksa status pesanan sebelum mencoba lagi.',
    413 => 'Ukuran unggahan terlalu besar. Gunakan gambar yang lebih kecil.',
    422 => 'Periksa kembali data yang diisi sebelum melanjutkan.',
    429 =>
      'Terlalu banyak percobaan. Tunggu beberapa saat sebelum mencoba lagi.',
    500 || 502 || 503 || 504 =>
      'Layanan sedang mengalami kendala. Coba lagi beberapa saat. Jika sudah membayar, periksa menu Status terlebih dahulu.',
    _ => 'Permintaan belum dapat diproses. Periksa koneksi lalu coba lagi.',
  };
}
