import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A failed request, with a message ready to show to the user.
class ApiError implements Exception {
  final String message;
  final int? status;

  ApiError(this.message, [this.status]);

  @override
  String toString() => message;
}

/// The `data` and `message` of a successful response.
class ApiResult {
  final dynamic data;
  final String? message;

  ApiResult(this.data, this.message);

  Map<String, dynamic> get map => mapOf(data);
}

/// The HTTP client of the app. Every endpoint answers `{success, message, data}`.
class Api {
  Api._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json', 'Accept-Language': 'ar'},
    ));
  }

  static final Api instance = Api._();

  late final Dio _dio;

  /// For example `https://hr.company.com/api`.
  String baseUrl = '';
  String? token;

  /// Called when the server rejects the token, so the app returns to the login screen.
  VoidCallback? onUnauthorized;

  Options get _options => Options(headers: {if (token != null) 'Authorization': 'Bearer $token'});

  String _url(String path) => '$baseUrl/${path.startsWith('/') ? path.substring(1) : path}';

  Future<ApiResult> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(_url(path), queryParameters: query, options: _options));

  Future<ApiResult> post(String path, {dynamic data}) =>
      _send(() => _dio.post(_url(path), data: data, options: _options));

  Future<ApiResult> _send(Future<Response> Function() call) async {
    if (baseUrl.isEmpty) {
      throw ApiError('حدد عنوان الخادم أولًا.');
    }
    try {
      final response = await call();
      final body = response.data;
      if (body is Map) {
        return ApiResult(body['data'], body['message'] as String?);
      }
      return ApiResult(body, null);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && token != null) {
        onUnauthorized?.call();
        throw ApiError('انتهت الجلسة. سجّل الدخول من جديد.', 401);
      }
      throw ApiError(_message(e), status);
    }
  }

  String _message(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    if (status != null && status >= 500) {
      return 'حدث خطأ في الخادم. حاول بعد قليل.';
    }
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return first is List && first.isNotEmpty ? first.first.toString() : first.toString();
      }
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'انتهت مهلة الاتصال بالخادم.';
      case DioExceptionType.connectionError:
        return 'تعذّر الاتصال بالخادم. تأكد من الإنترنت وعنوان الخادم.';
      default:
        break;
    }
    if (status == 403) return 'ليست لديك صلاحية لهذا الإجراء.';
    if (status == 404) return 'العنصر غير موجود.';
    return 'حدث خطأ غير متوقع.';
  }
}

// ── Reading JSON safely ──

Map<String, dynamic> mapOf(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> listOf(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

String str(dynamic value, [String fallback = '—']) {
  if (value == null) return fallback;
  final s = value.toString().trim();
  return s.isEmpty ? fallback : s;
}

num numOf(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

int intOf(dynamic value) => numOf(value).toInt();

bool boolOf(dynamic value) => value == true || value == 1 || value == '1';
