// screens/register.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:DigiDoc/models/DataBaseHelper.dart';
import 'package:DigiDoc/constants/color_app.dart';
import 'package:DigiDoc/router.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  bool _enableBiometric = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _register() async {
    final email = _emailController.text;
    final pin = _pinController.text;

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira um e-mail';
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
        _errorMessage = 'Por favor, insira um PIN';
      });
      return;
    }

    if (pin.length < 4) {
      setState(() {
        _errorMessage = 'O PIN deve ter pelo menos 4 dígitos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isEmailTaken = await DataBaseHelper.instance.validateIdentifier(email);
      if (isEmailTaken) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'E-mail já registrado';
        });
        return;
      }

      await DataBaseHelper.instance.registerUser(email, pin, _enableBiometric);
      context.goNamed(Routes.home.name);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao registrar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkerBlue,
      appBar: AppBar(
        title: const Text('Registo', style: TextStyle(color: Colors.white)),
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
              'Crie sua conta DigiDoc',
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
                fillColor: AppColors.calmWhite.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorText: _errorMessage,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              decoration: InputDecoration(
                labelText: 'PIN (mínimo 4 dígitos)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: AppColors.calmWhite.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text(
                'Ativar autenticação biométrica',
                style: TextStyle(color: Colors.white),
              ),
              value: _enableBiometric,
              onChanged: (value) {
                setState(() {
                  _enableBiometric = value ?? false;
                });
              },
              checkColor: AppColors.darkerBlue,
              activeColor: AppColors.lighterBlue,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.lighterBlue))
            else
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calmWhite,
                  foregroundColor: AppColors.darkerBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Registrar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.goNamed(Routes.login.name),
              child: const Text(
                'Já tem uma conta? Entrar',
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