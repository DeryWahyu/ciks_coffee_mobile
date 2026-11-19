import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppInfoService {
  static const _channel = MethodChannel('com.cikscoffee.app/app_info');

  Future<String?> version() async {
    try {
      final Map<String, dynamic>? data;
      if (kIsWeb) {
        final response = await http
            .get(Uri.base.resolve('version.json'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) return null;
        final version = jsonDecode(response.body) as Map<String, dynamic>;
        data = {
          'version': version['version'],
          'build': version['build_number'],
        };
      } else {
        data = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      }
      final version = data?['version']?.toString() ?? '';
      final build = data?['build']?.toString() ?? '';
      if (version.isEmpty) return null;
      return build.isEmpty ? version : '$version ($build)';
    } catch (_) {
      return null;
    }
  }

  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
