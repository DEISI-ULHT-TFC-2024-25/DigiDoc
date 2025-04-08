import 'dart:io';
import 'dart:typed_data';
import 'package:digidoc/DocumentScanner.dart';
import 'package:digidoc/ExtractedTextBox.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'DataBaseHelper.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'DocDetector.dart';
import 'screens/dossiers.dart';

class AppColors {
  static const Color mainSolidDarkerColor = Color.fromARGB(255, 26, 30, 59);
}

void main() {
  runApp(const MyApp());
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

//____________

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 1;
  String imgPath = '';

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      Center(child: Text("Definições", style: TextStyle(fontSize: 20))),
      DossiersScreen(),
      Center(child: Text("Alertas", style: TextStyle(fontSize: 20))),
    ];
    final List<String> _titles = [
      "Definições",
      "Os meus dossiers",
      "Alertas",
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.mainSolidDarkerColor,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Definições",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared),
            label: "Dossiers",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Alertas",
          ),
        ],
      ),
    );
  }

}

class RectangleOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromARGB(100, 0, 0, 0)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTRB(
      size.width * 0.05,
      size.height * 0.02,
      size.width * 0.95,
      size.height * 0.77,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(20),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
