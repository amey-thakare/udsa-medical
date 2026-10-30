import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Callback to handle forced logout on 401
  void Function()? onUnauthorized;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Diagnostic logging and auth interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          if (kDebugMode) {
            final safeHeaders = Map<String, dynamic>.from(options.headers);
            if (safeHeaders.containsKey('Authorization')) {
              safeHeaders['Authorization'] = 'Bearer [REDACTED]';
            }
            debugPrint('[HTTP REQUEST] ${options.method} ${options.baseUrl}${options.path}');
            if (options.data != null) {
              final safeData = _sanitizeData(options.data);
              debugPrint('[HTTP PAYLOAD] $safeData');
            }
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('[HTTP RESPONSE] ${response.statusCode} from ${response.requestOptions.path}');
            final safeBody = _sanitizeData(response.data);
            debugPrint('[HTTP RESPONSE BODY] $safeBody');
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint('[HTTP ERROR] ${error.type} for ${error.requestOptions.path}');
            if (error.response != null) {
              debugPrint('[HTTP ERROR STATUS] ${error.response?.statusCode}');
              debugPrint('[HTTP ERROR BODY] ${_sanitizeData(error.response?.data)}');
            } else {
              debugPrint('[HTTP ERROR MESSAGE] ${error.message}');
            }
          }

          if (error.response?.statusCode == 401) {
            await _storage.delete(key: 'token');
            await _storage.delete(key: 'user');
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static dynamic _sanitizeData(dynamic data) {
    if (data is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('password') || key.contains('token') || key.contains('secret')) {
          sanitized[entry.key.toString()] = '[REDACTED]';
        } else if (entry.value is Map || entry.value is List) {
          sanitized[entry.key.toString()] = _sanitizeData(entry.value);
        } else {
          sanitized[entry.key.toString()] = entry.value;
        }
      }
      return sanitized;
    } else if (data is List) {
      return data.map((item) => _sanitizeData(item)).toList();
    }
    return data;
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
  }
}
