import 'package:DigiDoc/pages/main_page.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:DigiDoc/models/DataBaseHelper.dart';
import 'package:DigiDoc/services/CurrentStateProcessing.dart';
import 'package:DigiDoc/constants/color_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  final firstCamera = cameras.isNotEmpty ? cameras.first : null;

  if (Platform.isAndroid) {
    await Permission.camera.request();
    await Permission.notification.request();
  }

  await initializeDateFormatting('pt_PT', null);

  final dbHelper = DataBaseHelper.instance;
  await dbHelper.getDossiers();

  runApp(
    ChangeNotifierProvider(
      create: (context) => CurrentStateProcessing(),
      child: MyApp(
        camera: firstCamera!,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiDoc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.darkerBlue),
        useMaterial3: true,
      ),
      supportedLocales: const [
        Locale('pt', 'PT'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('pt', 'PT'),
      home: MyHomePage(
        title: 'DigiDoc',
        camera: camera,
      ),
      routes: {
        '/alerts': (context) => const AlertsScreen(),
      },
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? payload = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      body: Center(child: Text('Alerta: ${payload ?? "Sem payload"}')),
    );
  }
}