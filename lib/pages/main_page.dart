import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/color_app.dart';
import '../screens/dossiers.dart';
import '../screens/alerts.dart' as alerts;
import '../screens/settings.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.camera,
    required this.page_index,
  });
  final String title;
  final CameraDescription? camera;
  final int page_index;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late int _selectedIndex;
  final GlobalKey<alerts.AlertsScreenState> _alertsScreenKey = GlobalKey<alerts.AlertsScreenState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.page_index;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      widget.camera == null
          ? const Center(child: Text('Nenhuma câmera disponível'))
          : DossiersScreen(camera: widget.camera!),
      alerts.AlertsScreen(key: _alertsScreenKey),
      const SettingsScreen(),
    ];
    final List<String> _titles = [
      "Os meus dossiers",
      "Alertas",
      "Definições",
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkPrimaryGradientStart.withAlpha(250)
            : AppColors.primaryGradientStart,
        title: Text(
          _titles[_selectedIndex],
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.calmWhite,
          ),
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            print('MyHomePage: Selecionado índice: $index');
            if (index == 1 && _alertsScreenKey.currentState != null) {
              print('MyHomePage: Chamando loadAlerts no AlertsScreen');
              _alertsScreenKey.currentState!.loadAlerts();
            }
          });
        },
        selectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.calmWhite
            : AppColors.primaryGradientStart,
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCardBackground
            : AppColors.cardBackground,
        selectedLabelStyle: GoogleFonts.poppins(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared),
            label: "Dossiers",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Alertas",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Definições",
          ),
        ],
      ),
    );
  }
}