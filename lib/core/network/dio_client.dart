// ============================================================
// RNA Guide - Dio Client
// HTTP avec interceptors JWT, refresh auto, retry offline
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:logger/logger.dart';

class DioClient {
  static final DioClient instance = DioClient._internal();
  DioClient._internal();

  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  final _log = Logger();

  static const String baseUrl = 'https://rna-guide-backend-production.up.railway.app/api/v1';
  // Dev local Android: 'http://10.0.2.2:3000/api/v1'
  // Dev local iOS:     'http://localhost:3000/api/v1'

  Future<void> initialize() async {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Version': '1.0.0',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage, _dio, _log),
      _LoggingInterceptor(_log),
    ]);
  }

  // ── Méthodes HTTP ─────────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return _dio.delete(path);
  }

  Future<Response> uploadFile(String path, FormData formData) async {
    return _dio.post(path, data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}));
  }

  Dio get dio => _dio;
}

// ── Interceptor JWT ───────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  final Logger _log;
  bool _isRefreshing = false;

  _AuthInterceptor(this._storage, this._dio, this._log);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final result = await _refreshToken();
        if (result == _RefreshResult.success) {
          final token = await _storage.read(key: 'access_token');
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          final response = await _dio.fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } else if (result == _RefreshResult.invalidToken) {
          // Refresh token révoqué ou expiré → déconnexion
          _log.w('Refresh token invalide — déconnexion');
          await _storage.deleteAll();
          Get.offAllNamed('/login');
        }
        // _RefreshResult.networkError → on laisse passer, l'utilisateur reste connecté
      } catch (e) {
        _log.e('Refresh inattendu: $e');
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }

  Future<_RefreshResult> _refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return _RefreshResult.invalidToken;

    try {
      final response = await Dio().post(
        '${DioClient.baseUrl}/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        await _storage.write(key: 'access_token', value: data['accessToken']);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        return _RefreshResult.success;
      }
      // 401/403 du backend = token révoqué
      return _RefreshResult.invalidToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return _RefreshResult.invalidToken;
      }
      // Erreur réseau ou serveur indisponible → ne pas déconnecter
      return _RefreshResult.networkError;
    } catch (_) {
      return _RefreshResult.networkError;
    }
  }
}

// ── Interceptor Logging ───────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  final Logger _log;
  _LoggingInterceptor(this._log);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log.d('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log.d('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.e('✗ ${err.response?.statusCode} ${err.requestOptions.path}: ${err.message}');
    handler.next(err);
  }
}

enum _RefreshResult { success, invalidToken, networkError }
