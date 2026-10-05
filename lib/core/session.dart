import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// The signed-in user: token, profile and what the app shows him.
class Session extends ChangeNotifier {
  static const _tokenKey = 'access_token';
  static const _serverKey = 'server_url';
  static const _profileKey = 'profile';

  final _secure = const FlutterSecureStorage();

  bool ready = false;
  String serverUrl = '';
  Map<String, dynamic> profile = {};

  bool get signedIn => Api.instance.token != null && profile.isNotEmpty;
  Map<String, dynamic> get user => mapOf(profile['user']);
  Map<String, dynamic> get employee => mapOf(profile['employee']);
  Map<String, dynamic> get company => mapOf(profile['company']);
  String get name => str(user['name'], '');
  String get firstName => str(employee['first_name'], name);
  String get role => str(user['role'], 'employee');
  String get roleLabel => str(user['role_label'], 'موظف');
  bool get isManager => boolOf(user['is_manager']);
  bool get isHr => boolOf(user['is_hr']);

  /// Reads the saved server, token and profile, then refreshes the profile from the server.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serverUrl = prefs.getString(_serverKey) ?? '';
      Api.instance.baseUrl = apiBase(serverUrl);
      Api.instance.onUnauthorized = () => _clear();
      String? token;
      try {
        token = await _secure.read(key: _tokenKey);
      } catch (_) {
        // Keys lost after a reinstall or backup restore: start signed out.
        try {
          await _secure.deleteAll();
        } catch (_) {}
      }
      final cached = prefs.getString(_profileKey);
      if (token != null && cached != null) {
        Api.instance.token = token;
        profile = mapOf(jsonDecode(cached));
        try {
          await refresh();
        } on ApiError catch (e) {
          if (e.status == 401) {
            await _clear();
          }
        }
      }
    } catch (_) {
      Api.instance.token = null;
      profile = {};
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> login(String server, String email, String password) async {
    final base = apiBase(server);
    if (base.isEmpty) {
      throw ApiError('اكتب عنوان خادم الشركة.');
    }
    Api.instance.baseUrl = base;
    Api.instance.token = null;
    final result = await Api.instance.post('login', data: {
      'email': email.trim(),
      'password': password,
      'device_name': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
    final data = result.map;
    final token = data['token'] as String?;
    if (token == null) {
      throw ApiError('استجابة غير متوقعة من الخادم.');
    }
    final prefs = await SharedPreferences.getInstance();
    serverUrl = server.trim();
    await prefs.setString(_serverKey, serverUrl);
    await _secure.write(key: _tokenKey, value: token);
    Api.instance.token = token;
    data.remove('token');
    await _saveProfile(data);
  }

  Future<void> refresh() async {
    final result = await Api.instance.get('me');
    await _saveProfile(result.map);
  }

  Future<void> logout() async {
    try {
      await Api.instance.post('logout');
    } catch (_) {
      // The token is dropped on this device either way.
    }
    await _clear();
  }

  Future<void> _saveProfile(Map<String, dynamic> data) async {
    profile = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(data));
    notifyListeners();
  }

  Future<void> _clear() async {
    Api.instance.token = null;
    profile = {};
    await _secure.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    notifyListeners();
  }

  /// `hr.company.com` → `https://hr.company.com/api`; a local address uses http.
  static String apiBase(String input) {
    var url = input.trim();
    if (url.isEmpty) return '';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final local = RegExp(r'^(\d{1,3}\.){3}\d{1,3}|^localhost').hasMatch(url);
      url = '${local ? 'http' : 'https'}://$url';
    }
    if (!url.endsWith('/api')) {
      url = '$url/api';
    }
    return url;
  }
}
