// pages/dossiers_page.dart
import 'package:flutter/material.dart';
import 'package:DigiDoc/constants/color_app.dart';
import 'package:DigiDoc/screens/dossiers.dart';

class DossiersPage extends StatelessWidget {
  const DossiersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dossiers'),
        backgroundColor: AppColors.darkerBlue,
      ),
      body: DossiersScreen(),
    );
  }
}