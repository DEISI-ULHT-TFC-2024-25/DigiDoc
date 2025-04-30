import 'package:DigiDoc/pages/main_page.dart';
import 'package:DigiDoc/screens/secutity.dart';
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
import 'services/alert_checker.dart';
import 'screens/auth.dart';

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
    final notificationStatus = await Permission.notification.request();
    print('Main: Status da permissão de notificação: $notificationStatus');
    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      print('Main: Permissão de notificação negada, solicitando novamente');
      await openAppSettings();
    }
    await Permission.scheduleExactAlarm.request();
  }

  // Inicializar formatação de data para pt_PT
  await initializeDateFormatting('pt_PT', null);

  // Inicializar banco de dados
  final dbHelper = DataBaseHelper.instance;
  await dbHelper.getDossiers();

  // Iniciar verificação de alertas
  startAlertChecker(navigatorKey);

  runApp(
    ChangeNotifierProvider(
      create: (context) => CurrentStateProcessing(),
      child: MyApp(
        camera: firstCamera,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final CameraDescription? camera;

  const MyApp({
    Key? key,
    required this.camera,
  }) : super(key: key);

  Future<bool> _hasPin() async {
    final userData = await DataBaseHelper.instance.query('User_data');
    return userData.isNotEmpty && userData.first['pin_hash'] == null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasPin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final hasPin = snapshot.data ?? false;
        return MaterialApp(
          navigatorKey: navigatorKey,
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
          home: hasPin
              ? const AuthScreen()
              : MyHomePage(
            title: 'DigiDoc',
            camera: camera,
            page_index: 0,
          ),
          routes: {
            '/alerts': (context) => MyHomePage(
              title: 'DigiDoc',
              camera: camera,
              page_index: 2,
            ),
            '/home': (context) => MyHomePage(
              title: 'DigiDoc',
              camera: camera,
              page_index: 0,
            ),
            '/security': (context) => const SecurityScreen(),
          },
        );
      },
    );
  }
}