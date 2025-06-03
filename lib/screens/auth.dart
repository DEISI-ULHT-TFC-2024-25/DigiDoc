import 'package:DigiDoc/screens/security.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import 'forgot_pin.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _pinController = TextEditingController();
  String? _email;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  final _localAuth = LocalAuthentication();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('AuthScreen: initState chamado');
    _loadUserData();
    _checkBiometricSupport();
  }

  Future<void> _loadUserData() async {
    if (_isLoading) return; // Evitar múltiplas chamadas
    setState(() {
      _isLoading = true;
    });
    try {
      final userData = await DataBaseHelper.instance.query('User_data');
      print('AuthScreen: Dados do usuário carregados: $userData');
      if (userData.isNotEmpty) {
        setState(() {
          _email = userData.first['email'] as String?;
          _isBiometricEnabled = userData.first['biometric_enabled'] == 1;
        });
        print('AuthScreen: Email: $_email, Biometria habilitada: $_isBiometricEnabled');
      } else {
        print('AuthScreen: Nenhum usuário encontrado, redirecionando para /security');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SecurityScreen(),
          ),
        );
      }
    } catch (e) {
      print('AuthScreen: Erro ao carregar dados do usuário: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final isDeviceSupported = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      setState(() {
        _isBiometricAvailable = isDeviceSupported && availableBiometrics.isNotEmpty;
      });
      print('AuthScreen: Biometria disponível: $_isBiometricAvailable, Biometrias: $availableBiometrics');
    } catch (e) {
      print('AuthScreen: Erro ao verificar suporte biométrico: $e');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_isBiometricAvailable || !_isBiometricEnabled || _email == null) {
      print('AuthScreen: Biometria não disponível ou desativada, email: $_email');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autenticação biométrica não disponível ou desativada')),
      );
      return;
    }

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Use biometria para acessar o DigiDoc',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (didAuthenticate) {
        print('AuthScreen: Autenticação biométrica bem-sucedida, redirecionando para /home');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        print('AuthScreen: Falha na autenticação biométrica');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha na autenticação biométrica')),
        );
      }
    } catch (e) {
      print('AuthScreen: Erro na autenticação biométrica: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na autenticação biométrica: $e')),
      );
    }
  }

  Future<void> _validatePin() async {
    if (_isLoading) return;
    if (_email == null) {
      print('AuthScreen: Email não carregado, não é possível validar PIN');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum usuário registrado')),
      );
      return;
    }
    if (_pinController.text.isEmpty) {
      print('AuthScreen: PIN não inserido');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira o PIN')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      bool isValid = await DataBaseHelper.instance.validatePin(_email!, _pinController.text);
      if (isValid) {
        print('AuthScreen: PIN válido, redirecionando para /home');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        print('AuthScreen: PIN inválido');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN inválido')),
        );
      }
    } catch (e) {
      print('AuthScreen: Erro ao validar PIN: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao validar PIN: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('AuthScreen: Construindo tela, email: $_email, biometria habilitada: $_isBiometricEnabled');
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Digite o PIN de Acesso',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isBiometricAvailable && _isBiometricEnabled
                      ? IconButton(
                    icon: const Icon(Icons.fingerprint, color: AppColors.darkerBlue),
                    onPressed: _isLoading ? null : _authenticateWithBiometrics,
                  )
                      : null,
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _validatePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkerBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('Entrar', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                  print('AuthScreen: Navegando para ForgotPinScreen');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPinScreen()),
                  );
                },
                child: const Text('Esqueci o PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}