// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:DigiDoc/constants/color_app.dart';
import 'package:DigiDoc/pages/auth_page.dart';
import 'package:DigiDoc/pages/dossiers_page.dart';
import 'package:DigiDoc/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'DigiDoc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.darkerBlue),
        useMaterial3: true,
      ),
      home: authState.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(body: Center(child: Text('Error: $error'))),
        data: (isAuthenticated) => isAuthenticated ? const DossiersPage() : const AuthPage(),
      ),
    );
  }
}