import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP client for the sync API.
///
/// Mirrors the mobile app's ApiService: same endpoint contract, Bearer-token
/// interceptor, and token persistence. [baseUrl] and [dio] are injectable so
/// tests can point at a mock server.
class ApiService {
  final Dio _dio;
  static const String _baseUrl = 'https://notes-api.scaleitpro.com/api/';
  static const String _tokenKey = 'auth_token';

  ApiService({String? baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? _baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            )) {
    if (dio == null) {
      _dio.options.baseUrl = baseUrl ?? _dio.options.baseUrl;
    }
    // Always attach the token interceptor so injected Dio instances
    // (e.g. from tests) behave identically to the default client.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<Response> post(String path, dynamic data) => _dio.post(path, data: data);
  Future<Response> get(String path) => _dio.get(path);

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
