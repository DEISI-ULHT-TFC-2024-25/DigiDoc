import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../constants/color_app.dart';
import '../screens/dossiers.dart';
import '../screens/alerts.dart' as alerts;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.camera});
  final String title;
  final CameraDescription? camera; // Alterado para CameraDescription?

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final GlobalKey<alerts.AlertsScreenState> _alertsScreenKey = GlobalKey<alerts.AlertsScreenState>();

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      widget.camera == null
          ? const Center(child: Text('Nenhuma câmera disponível'))
          : DossiersScreen(camera: widget.camera!), // Passar camera não nulo
      alerts.AlertsScreen(key: _alertsScreenKey),
    ];
    final List<String> _titles = [
      "Os meus dossiers",
      "Alertas",
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkerBlue,
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
            print('MyHomePage: Selecionado índice: $index');
            if (index == 1 && _alertsScreenKey.currentState != null) {
              print('MyHomePage: Chamando loadAlerts no AlertsScreen');
              _alertsScreenKey.currentState!.loadAlerts();
            }
          });
        },
        items: const [
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