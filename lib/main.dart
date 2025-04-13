import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/CurrentStateProcessing.dart';
import 'screens/main_page.dart';
import 'constants/color_app.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CurrentStateProcessing(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiDoc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.mainSolidDarkerColor),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Confirmação de dados'),
    );
  }
}