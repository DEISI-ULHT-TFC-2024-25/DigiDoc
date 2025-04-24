// auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:DigiDoc/models/DataBaseHelper.dart';
import 'package:local_auth/local_auth.dart';

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AsyncValue<bool>>((ref) {
  return AuthStateNotifier();
});

class AuthStateNotifier extends StateNotifier<AsyncValue<bool>> {
  final DataBaseHelper _dbHelper = DataBaseHelper.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthStateNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    state = const AsyncValue.loading();
    try {
      final isRegistered = await _dbHelper.isUserRegistered();
      state = AsyncValue.data(isRegistered);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> register(String email) async {
    state = const AsyncValue.loading();
    try {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('Por favor, insira um e-mail válido');
      }

      final isEmailTaken = await _dbHelper.validateIdentifier(email);
      if (isEmailTaken) {
        throw Exception('E-mail já registrado');
      }

      state = const AsyncValue.data(true);
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<bool> authenticateWithBiometrics(String email) async {
    try {
      final isBiometricEnabled = await _dbHelper.isBiometricEnabled(email);
      if (!isBiometricEnabled) return false;

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentique-se para acessar o DigiDoc',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      return authenticated;
    } catch (e) {
      print('Erro na autenticação biométrica: $e');
      return false;
    }
  }
}