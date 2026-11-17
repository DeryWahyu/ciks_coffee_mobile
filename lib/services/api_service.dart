import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table_layout_model.dart';
import '../models/user_model.dart';

enum SessionStatus { valid, unauthenticated, unavailable }

class ApiService {
  ApiService({http.Client? client}) : _client = client;
  final http.Client? _client;
  static const _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _tokenExpiryKey = 'auth_token_expires_at';
  static const currentBaseUrl = 'https://cikscoffee.biz.id/api';
  static final _sessionEnded = StreamController<void>.broadcast(sync: true);
  static final _cartReset = StreamController<void>.broadcast(sync: true);
  static Stream<void> get sessionEnded => _sessionEnded.stream;
  static Stream<void> get cartResets => _cartReset.stream;
  static Future<void> _tokenQueue = Future.value();
  static int _sessionVersion = 0;
  static int get sessionVersion => _sessionVersion;

  static Future<void> _mutateToken(Future<void> Function() operation) {
    final next = _tokenQueue.then((_) => operation());
    _tokenQueue = next.catchError((Object _) {});
    return next;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('custom_api_base_url');
    if (saved != null &&
        saved.trim().replaceAll(RegExp(r'/+$'), '') != currentBaseUrl) {
      await ApiService().clearToken();
    }
    await prefs.remove('custom_api_base_url');
  }

  String get baseUrl => currentBaseUrl;
  String get hostUrl => baseUrl.replaceFirst(RegExp(r'/api$'), '');
  String getImageUrl(String path) {
    if (path.isEmpty) return '';
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) {
      return uri.scheme == 'https' || uri.scheme == 'http' ? path : '';
    }
    return '$baseUrl/image/${path.replaceFirst(RegExp(r'^storage/'), '')}';
  }

  Future<void> _setIdentity(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('session_user_id') != userId) await _resetCart();
    await prefs.setInt('session_user_id', userId);
  }

  Future<void> _resetCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart_data');
    await prefs.remove('pending_checkout');
    _cartReset.add(null);
  }

  Future<void> saveToken(String token, {String? expiresAt}) {
    _sessionVersion++;
    return _mutateToken(() async {
      await _secureStorage.write(key: _tokenKey, value: token);
      if (expiresAt != null && expiresAt.isNotEmpty) {
        await _secureStorage.write(key: _tokenExpiryKey, value: expiresAt);
      } else {
        await _secureStorage.delete(key: _tokenExpiryKey);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    });
  }

  Future<String?> getToken() async {
    var token = await _secureStorage.read(key: _tokenKey);
    if (token != null) {
      final expiry = DateTime.tryParse(
        await _secureStorage.read(key: _tokenExpiryKey) ?? '',
      );
      if (expiry != null && !expiry.isAfter(DateTime.now())) {
        await clearToken();
        return null;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
      if (token != null) await saveToken(token);
    }
    return token;
  }

  Future<void> clearToken({String? expectedToken}) {
    final version = ++_sessionVersion;
    return _mutateToken(() async {
      if (expectedToken != null &&
          await _secureStorage.read(key: _tokenKey) != expectedToken) {
        return;
      }
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove('session_user_id');
      await prefs.remove('user_name');
      await _resetCart();
      if (version == _sessionVersion) _sessionEnded.add(null);
    });
  }

  Future<http.Response> _send(
    http.BaseRequest request, {
    String? token,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = _client ?? http.Client();
    try {
      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      // A late response from an old session must not sign out the next account.
      if (token != null) {
        if (await _secureStorage.read(key: _tokenKey) != token) {
          throw StateError('Sesi akun telah berubah.');
        }
        if (response.statusCode == 401) await clearToken(expectedToken: token);
      }
      return response;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final token = authenticated ? await getToken() : null;
    if (authenticated && token == null) {
      return http.Response(
        '{"message":"Sesi telah berakhir. Silakan login ulang."}',
        401,
      );
    }
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Ciks-Checkout-Version': '2',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    return _send(request, token: token);
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      /* Friendly error below. */
    }
    return {};
  }

  Map<String, dynamic> _failure(http.Response response) {
    final data = _decode(response.body), errors = data['errors'];
    final first = errors is Map && errors.isNotEmpty
        ? errors.values.first
        : null;
    return {
      'success': false,
      'status': response.statusCode,
      'message': first is List && first.isNotEmpty
          ? first.first.toString()
          : data['message']?.toString() ??
                'Server belum dapat memproses permintaan (${response.statusCode}).',
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _sessionVersion++;
    try {
      final response = await _request(
        'POST',
        '/login',
        body: {'email': email, 'password': password},
        authenticated: false,
      );
      if (response.statusCode != 200) return _failure(response);
      final data = _decode(response.body),
          user = UserModel.fromJson(Map<String, dynamic>.from(data['user']));
      await saveToken(data['access_token'], expiresAt: data['expires_at']);
      await _setIdentity(user.id);
      return {'success': true, 'user': user};
    } catch (_) {
      return {
        'success': false,
        'message': 'Koneksi ke server gagal. Silakan coba lagi.',
      };
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    try {
      final r = await _request(
        'POST',
        '/register',
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        },
        authenticated: false,
      );
      if (r.statusCode != 201) return _failure(r);
      return {
        'success': true,
        'user': UserModel.fromJson(
          Map<String, dynamic>.from(_decode(r.body)['user']),
        ),
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Koneksi ke server gagal. Silakan coba lagi.',
      };
    }
  }

  Future<SessionStatus> validateSession() async {
    try {
      if (await getToken() == null) return SessionStatus.unauthenticated;
      final r = await _request('GET', '/user');
      if (r.statusCode == 200) {
        final user = _decode(r.body);
        if (user['role'] != 'pengguna') {
          await clearToken();
          return SessionStatus.unauthenticated;
        }
        await _setIdentity(user['id'] as int);
        return SessionStatus.valid;
      }
      if (r.statusCode == 401 || r.statusCode == 403) {
        if (r.statusCode == 403) await clearToken();
        return SessionStatus.unauthenticated;
      }
    } catch (error) {
      debugPrint('[Session] Server unavailable: $error');
    }
    return SessionStatus.unavailable;
  }

  Future<bool> validateToken() async =>
      await validateSession() == SessionStatus.valid;
  Future<void> logout({String? deviceToken}) async {
    try {
      await _request(
        'POST',
        '/logout',
        body: {'device_token': ?deviceToken},
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Local logout always works. */
    }
    await clearToken();
  }

  Future<bool> registerDeviceToken(String token) async {
    try {
      final r = await _request(
        'POST',
        '/device-tokens',
        body: {'token': token, 'platform': 'android'},
      );
      return r.statusCode == 200 || r.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unregisterDeviceToken(String token) async {
    try {
      return (await _request(
            'DELETE',
            '/device-tokens',
            body: {'token': token},
          )).statusCode ==
          200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _get(String path, {bool envelope = true}) async {
    try {
      final r = await _request('GET', path);
      if (r.statusCode != 200) return _failure(r);
      final data = _decode(r.body);
      if (data.isEmpty) {
        return {
          'success': false,
          'message': 'Respons server tidak valid. Silakan coba lagi.',
        };
      }
      return {'success': true, 'data': envelope ? data['data'] : data};
    } catch (_) {
      return {
        'success': false,
        'message': 'Koneksi terputus. Silakan coba lagi.',
      };
    }
  }

  Future<Map<String, dynamic>> _getList(String path) async {
    final result = await _get(path);
    if (result['success'] == true &&
        (result['data'] is! List ||
            !(result['data'] as List).every((row) => row is Map))) {
      return {
        'success': false,
        'message': 'Respons server tidak valid. Silakan coba lagi.',
      };
    }
    return result;
  }

  Future<Map<String, dynamic>> getCategories() => _getList('/categories');
  Future<Map<String, dynamic>> getProducts({int? categoryId, String? search}) {
    final query = Uri(
      queryParameters: {
        if (categoryId != null && categoryId != 0) 'category_id': '$categoryId',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    ).query;
    return _getList('/products${query.isEmpty ? '' : '?$query'}');
  }

  Future<Map<String, dynamic>> getActiveOrders() => _getList('/orders/active');
  Future<Map<String, dynamic>> getOrderHistory() => _getList('/orders/history');
  Future<Map<String, dynamic>> getProfile() => _get('/user', envelope: false);
  Future<Map<String, dynamic>> confirmPickup(int orderId) async {
    try {
      final r = await _request('POST', '/orders/$orderId/pickup');
      if (r.statusCode != 200) return _failure(r);
      return {
        'success': true,
        'message': _decode(r.body)['message'] ?? 'Berhasil',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Koneksi terputus. Silakan coba lagi.',
      };
    }
  }

  Future<Map<String, dynamic>> getQrisImage() async {
    final result = await _get('/shop/qris', envelope: false),
        data = result['data'];
    if (result['success'] == true && data?['success'] == true) {
      return {
        'success': true,
        'image_url': getImageUrl(data['data']['image_url'] ?? ''),
      };
    }
    return {
      'success': false,
      'message':
          result['message'] ?? data?['message'] ?? 'QRIS belum tersedia.',
    };
  }

  Future<Map<String, dynamic>> getTableLayout() async {
    final result = await _get('/table-layout', envelope: false),
        body = result['data'];
    if (result['success'] == true &&
        body?['success'] == true &&
        body?['data'] is Map) {
      return {
        'success': true,
        'data': TableLayoutData.fromJson(
          Map<String, dynamic>.from(body['data']),
        ),
      };
    }
    return {
      'success': false,
      'message':
          result['message'] ?? body?['message'] ?? 'Denah belum dapat dimuat.',
    };
  }

  static String _newKey() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    // Keep UUID generation independent of platform plugins.
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, dynamic>?> pendingCheckout() async {
    final prefs = await SharedPreferences.getInstance(),
        saved = (await SharedPreferences.getInstance()).getString(
          'pending_checkout',
        );
    if (saved != null) return _decode(saved);
    final current = await _get('/checkouts/current');
    if (current['success'] != true) {
      throw StateError(
        current['message'] ?? 'Pembayaran belum dapat diperiksa.',
      );
    }
    if (current['data'] == null) return null;
    final quote = Map<String, dynamic>.from(current['data']);
    final pending = {
      'request_key': quote['request_key'],
      'items': quote['items'],
      'expected_total': quote['total'],
      'checkout_id': quote['id'],
    };
    await prefs.setString('pending_checkout', jsonEncode(pending));
    return pending;
  }

  Future<Map<String, dynamic>> prepareCheckout({
    required List<Map<String, dynamic>> items,
    required double expectedTotal,
    Map<String, dynamic>? pending,
    String? cartId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload =
          pending ??
          {
            'request_key': _newKey(),
            'items': items,
            'expected_total': expectedTotal,
            'local_cart_id': cartId,
          };
      if (!await prefs.setString('pending_checkout', jsonEncode(payload))) {
        throw StateError('Sesi pembayaran belum dapat disimpan.');
      }
      final r = await _request('POST', '/checkouts', body: payload);
      if (r.statusCode != 201) {
        if (r.statusCode == 422 && payload['checkout_id'] == null) {
          await prefs.remove('pending_checkout');
        }
        return _failure(r);
      }
      final quote = Map<String, dynamic>.from(_decode(r.body)['data']);
      quote['local_cart_id'] = payload['local_cart_id'];
      await prefs.setString(
        'pending_checkout',
        jsonEncode({
          'request_key': quote['request_key'],
          'items': quote['items'],
          'expected_total': quote['total'],
          'checkout_id': quote['id'],
          'local_cart_id': payload['local_cart_id'],
        }),
      );
      return {'success': true, 'data': quote};
    } catch (_) {
      return {
        'success': false,
        'message':
            'Pembayaran belum dapat diperiksa. Coba lagi untuk melanjutkan sesi yang sama.',
      };
    }
  }

  Future<void> clearPendingCheckout({String? checkoutId}) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString('pending_checkout');
    if (checkoutId != null &&
        pending != null &&
        _decode(pending)['checkout_id'] != checkoutId) {
      return;
    }
    await prefs.remove('pending_checkout');
  }

  Future<bool> cancelCheckout(String id) async {
    try {
      final r = await _request('DELETE', '/checkouts/$id');
      if (r.statusCode == 200) {
        await clearPendingCheckout(checkoutId: id);
        return true;
      }
    } catch (_) {
      /* Retry the same reservation. */
    }
    return false;
  }

  Future<Map<String, dynamic>> checkout({
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    double? cashReceived,
    String? paymentProofPath,
    String? checkoutId,
  }) async {
    try {
      final token = await getToken(),
          request = http.MultipartRequest('POST', Uri.parse('$baseUrl/orders'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.fields['payment_method'] = paymentMethod;
      if (checkoutId != null) request.fields['checkout_id'] = checkoutId;
      for (var i = 0; i < items.length; i++) {
        for (final key in ['product_id', 'quantity', 'price', 'variant']) {
          if (items[i][key] != null) {
            request.fields['items[$i][$key]'] = '${items[i][key]}';
          }
        }
      }
      if (paymentProofPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('payment_proof', paymentProofPath),
        );
      }
      final r = await _send(
        request,
        token: token,
        timeout: const Duration(seconds: 30),
      );
      if (r.statusCode != 200 && r.statusCode != 201) return _failure(r);
      return {'success': true, 'data': _decode(r.body)};
    } catch (_) {
      return {
        'success': false,
        'message':
            'Hasil pengiriman belum dapat diperiksa. Coba lagi untuk melanjutkan pembayaran yang sama.',
      };
    }
  }
}
