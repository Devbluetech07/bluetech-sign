import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_flutter/core/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    
    bool success;
    if (_isRegister) {
      success = await authProvider.register(
        _emailController.text,
        _passwordController.text,
        _nomeController.text,
      );
    } else {
      success = await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao ${_isRegister ? "cadastrar" : "entrar"}. Verifique seus dados.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
               BoxShadow(
                 color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                 blurRadius: 30,
                 spreadRadius: -10,
               )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Valeris',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isRegister ? 'Crie sua conta' : 'Acesse a central',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isRegister) ...[
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome Completo'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isRegister ? 'Cadastrar' : 'Entrar'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister ? 'Já tenho conta, entrar' : 'Ainda não tenho conta, cadastrar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
