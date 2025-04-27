import 'package:DigiDoc/pages/main_page.dart';
import 'package:DigiDoc/screens/dossiers.dart';
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
import 'package:DigiDoc/screens/alerts.dart';
import 'services/notification_service.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar câmeras
  final cameras = await availableCameras();
  final firstCamera = cameras.isNotEmpty ? cameras.first : null;

  // Inicializar notificações
  await initNotifications(navigatorKey);

  // Solicitar permissões no Android
  if (Platform.isAndroid) {
    await Permission.camera.request();
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  // Inicializar formatação de data para pt_PT
  await initializeDateFormatting('pt_PT', null);

  // Inicializar banco de dados
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
      navigatorKey: navigatorKey, // Usar a chave global definida
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