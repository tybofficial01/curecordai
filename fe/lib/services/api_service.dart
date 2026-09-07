import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class ApiService {
  static const String _baseUrl = 'http://localhost:8000/api/v1';
  static const Duration _timeout = Duration(seconds: 15);

  final StorageService _storage;

  ApiService(this._storage);

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return response;
    } on Exception {
      throw NetworkException('No internet connection. Please try again.');
    }
  }

  Future<http.Response> postAuth(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: await _headers(auth: true),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (response.statusCode == 401) {
        await _storage.deleteToken();
        throw UnauthorizedException('Session expired. Please log in again.');
      }
      return response;
    } on UnauthorizedException {
      rethrow;
    } on Exception {
      throw NetworkException('No internet connection. Please try again.');
    }
  }

  Future<http.Response> get(String endpoint) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl$endpoint'),
            headers: await _headers(auth: true),
          )
          .timeout(_timeout);
      if (response.statusCode == 401) {
        await _storage.deleteToken();
        throw UnauthorizedException('Session expired. Please log in again.');
      }
      return response;
    } on UnauthorizedException {
      rethrow;
    } on Exception {
      throw NetworkException('No internet connection. Please try again.');
    }
  }
}
