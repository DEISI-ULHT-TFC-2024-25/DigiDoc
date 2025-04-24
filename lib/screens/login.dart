// screens/login.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:DigiDoc/models/DataBaseHelper.dart';
import 'package:DigiDoc/constants/color_app.dart';
import 'package:DigiDoc/router.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  bool _usePin = false;
  bool _isLoading = false;
  String? _errorMessage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _tryBiometricAuth();
  }

  Future<void> _tryBiometricAuth() async {
    final email = _emailController.text;
    if (email.isEmpty) return;

    final isBiometricEnabled = await DataBaseHelper.instance.isBiometricEnabled(email);
    if (isBiometricEnabled) {
      try {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Autentique-se para acessar o DigiDoc',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (authenticated) {
          _navigateToHome();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Autenticação biométrica falhou';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro na autenticação biométrica: $e';
        });
      }
    }
  }

  Future<void> _loginWithPin() async {
    final email = _emailController.text;
    final pin = _pinController.text;

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira o e-mail';
      });
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Por favor, insira um e-mail válido';
      });
      return;
    }

    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira o PIN';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await DataBaseHelper.instance.validatePin(email, pin);
      if (isValid) {
        _navigateToHome();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'E-mail ou PIN incorretos';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao autenticar: $e';
      });
    }
  }

  void _navigateToHome() {
    context.goNamed(Routes.home.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkerBlue,
      appBar: AppBar(
        title: const Text('Autenticação', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkerBlue,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bem-vindo ao DigiDoc',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'E-mail',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: AppColors.calmWhite.withAlpha(30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorText: _errorMessage,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() => _errorMessage = null),
            ),
            const SizedBox(height: 16),
            if (_usePin)
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: AppColors.calmWhite.withAlpha(30),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() => _errorMessage = null),
              ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.lighterBlue))
            else
              ElevatedButton(
                onPressed: _usePin ? _loginWithPin : _tryBiometricAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calmWhite,
                  foregroundColor: AppColors.darkerBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _usePin ? 'Entrar com PIN' : 'Entrar com Biometria',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _usePin = !_usePin),
              child: Text(
                _usePin ? 'Usar Biometria' : 'Usar PIN',
                style: const TextStyle(color: AppColors.lighterBlue),
              ),
            ),
            TextButton(
              onPressed: () => context.goNamed(Routes.register.name),
              child: const Text(
                'Registrar-se',
                style: TextStyle(color: AppColors.lighterBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}