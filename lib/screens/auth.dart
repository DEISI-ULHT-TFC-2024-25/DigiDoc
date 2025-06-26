import 'package:DigiDoc/screens/security.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import '../services/current_state_processing.dart';
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
    if (_isLoading) return;
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
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SecurityScreen()),
          );
        }
      }
    } catch (e) {
      print('AuthScreen: Erro ao carregar dados do usuário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autenticação biométrica não disponível ou desativada')),
        );
      }
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
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        print('AuthScreen: Falha na autenticação biométrica');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha na autenticação biométrica')),
          );
        }
      }
    } catch (e) {
      print('AuthScreen: Erro na autenticação biométrica: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na autenticação biométrica: $e')),
        );
      }
    }
  }

  Future<void> _validatePin() async {
    if (_isLoading) return;
    if (_email == null) {
      print('AuthScreen: Email não carregado, não é possível validar PIN');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum usuário registrado')),
        );
      }
      return;
    }
    if (_pinController.text.isEmpty) {
      print('AuthScreen: PIN não inserido');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insira o PIN')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      bool isValid = await DataBaseHelper.instance.validatePin(_email!, _pinController.text);
      if (isValid) {
        print('AuthScreen: PIN válido, redirecionando para /home');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        print('AuthScreen: PIN inválido');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN inválido')),
          );
        }
      }
    } catch (e) {
      print('AuthScreen: Erro ao validar PIN: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao validar PIN: $e')),
        );
      }
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
    final themeProvider = Provider.of<CurrentStateProcessing>(context);

    return Scaffold(
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.background,
        child: SafeArea(
          child: Center(
            child: _isLoading
                ? CircularProgressIndicator(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkPrimaryGradientStart
                  : AppColors.darkerBlue,
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'web/icons/Icon-512.png',
                    height: 120,
                    width: 120,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkCardBackground.withOpacity(0.9)
                          : AppColors.cardBackground.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black54
                              : Colors.black12.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bem-vindo ao DigiDoc',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : AppColors.primaryGradientStart,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _pinController,
                          decoration: InputDecoration(
                            labelText: 'Digite seu PIN',
                            labelStyle: GoogleFonts.poppins(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkCardBackground.withOpacity(0.8)
                                : AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkPrimaryGradientStart
                                    : AppColors.primaryGradientStart,
                                width: 2,
                              ),
                            ),
                          ),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _validatePin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkPrimaryGradientStart
                                : AppColors.primaryGradientStart,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            'Entrar',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.calmWhite,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (_isBiometricAvailable && _isBiometricEnabled && !_isLoading)
                          FloatingActionButton(
                            onPressed: _authenticateWithBiometrics,
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkPrimaryGradientStart
                                : AppColors.darkerBlue,
                            child: Icon(
                              Icons.fingerprint,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.calmWhite,
                            ),
                            mini: true,
                          ),
                        const SizedBox(height: 10),
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
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkPrimaryGradientStart
                                : AppColors.primaryGradientStart,
                          ),
                          child: Text(
                            'Esqueci o PIN',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.calmWhite
                                  : AppColors.primaryGradientStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}