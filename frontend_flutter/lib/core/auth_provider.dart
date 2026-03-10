import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class User {
  final String id;
  final String email;
  final String nomeCompleto;

  User({required this.id, required this.email, required this.nomeCompleto});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      nomeCompleto: json['nome_completo'] ?? '',
    );
  }
}

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null) {
      try {
        final res = await apiClient.get('/auth/me');
        if (res.statusCode == 200) {
          _user = User.fromJson(jsonDecode(res.body));
        } else {
          await prefs.remove('jwt_token');
        }
      } catch (e) {
        // error validating
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await apiClient.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        _user = User.fromJson(data['user']);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String email, String password, String nomeCompleto) async {
    try {
      final res = await apiClient.post('/auth/register', {
        'email': email,
        'password': password,
        'nome_completo': nomeCompleto,
      });

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        _user = User.fromJson(data['user']);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _user = null;
    notifyListeners();
  }
}
