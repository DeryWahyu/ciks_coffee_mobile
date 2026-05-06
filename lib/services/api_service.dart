import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class ApiService {
  String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.18.189:8000/api';
      }
    } catch (_) {
      // Ignore platform access error if not web and not recognized
    }
    return 'http://127.0.0.1:8000/api';
  }

  String get hostUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.18.189:8000';
      }
    } catch (_) {
      // Ignore platform access error if not web and not recognized
    }
    return 'http://127.0.0.1:8000';
  }

  String getImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    
    // Replace 'storage/' prefix if present, as our API route takes the raw path
    if (path.startsWith('storage/')) {
      path = path.replaceFirst('storage/', '');
    }
    
    return '$baseUrl/image/$path';
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        try {
          final data = jsonDecode(response.body);
          return {'success': false, 'message': data['message'] ?? 'Login failed'};
        } catch (_) {
          return {'success': false, 'message': 'Server error: ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi ke server gagal. Pastikan server berjalan. ($e)'};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Token tidak disimpan otomatis agar user diarahkan untuk login
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      } else {
        try {
          final data = jsonDecode(response.body);
          return {'success': false, 'message': data['message'] ?? 'Registration failed'};
        } catch (_) {
          return {'success': false, 'message': 'Server error: ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi ke server gagal. Pastikan server berjalan. ($e)'};
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ignore errors during logout request
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<Map<String, dynamic>> getCategories() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Gagal mengambil kategori'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> getProducts({int? categoryId, String? search}) async {
    try {
      final token = await getToken();
      String url = '$baseUrl/products?';
      if (categoryId != null && categoryId != 0) {
        url += 'category_id=$categoryId&';
      }
      if (search != null && search.isNotEmpty) {
        url += 'search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Gagal mengambil produk'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }
}
