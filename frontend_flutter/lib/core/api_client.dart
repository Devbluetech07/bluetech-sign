import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:3001/api';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String path) async {
    return http.get(Uri.parse('$baseUrl$path'), headers: await _getHeaders());
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    return http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path) async {
    return http.delete(Uri.parse('$baseUrl$path'), headers: await _getHeaders());
  }
}

final apiClient = ApiClient();
