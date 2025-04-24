import 'package:flutter/material.dart';
import '../constants/color_app.dart';
import '../screens/dossiers.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 1;

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