import 'package:DigiDoc/pages/main_page.dart';
import 'package:DigiDoc/screens/create_new_pin.dart';
import 'package:DigiDoc/screens/security.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:DigiDoc/models/data_base_helper.dart';
import 'package:DigiDoc/services/current_state_processing.dart';
import 'package:DigiDoc/constants/color_app.dart';
import 'package:DigiDoc/services/notification_service.dart';
import 'package:DigiDoc/services/alert_checker.dart';
import 'package:DigiDoc/screens/auth.dart';
import 'package:DigiDoc/screens/forgot_pin.dart';
import 'package:google_fonts/google_fonts.dart';


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
    final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
    print('Main: Status da permissão de bateria: $batteryStatus');
    if (batteryStatus.isDenied || batteryStatus.isPermanentlyDenied) {
      print('Main: Permissão de bateria negada, solicitando novamente');
    }
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

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrentStateProcessing>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'DigiDoc',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.darkerBlue,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: AppColors.background,
            cardColor: AppColors.cardBackground,
            textTheme: GoogleFonts.poppinsTextTheme(),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.darkerBlue,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.grey[900],
            cardColor: Colors.grey[800],
            textTheme: GoogleFonts.poppinsTextTheme().apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            useMaterial3: true,
          ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
          home: const AuthScreen(),
          routes: {
            '/alerts': (context) => MyHomePage(
              title: 'DigiDoc',
              camera: camera,
              page_index: 1,
            ),
            '/home': (context) => MyHomePage(
              title: 'DigiDoc',
              camera: camera,
              page_index: 0,
            ),
            '/security': (context) => const SecurityScreen(),
            '/forgot_pin': (context) => const ForgotPinScreen(),
            '/create_new_pin': (context) => const CreateNewPinScreen(),
          },
        );
      },
    );
  }
}