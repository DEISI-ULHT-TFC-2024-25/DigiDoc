// router.dart
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:DigiDoc/screens/dossiers.dart';
import 'package:DigiDoc/screens/dossier.dart';
import 'package:DigiDoc/screens/capture_document_photo.dart';
import 'package:DigiDoc/screens/upload_document.dart';
import 'package:DigiDoc/screens/info_confirmation.dart';
import 'package:DigiDoc/pages/main_page.dart';
import 'package:DigiDoc/screens/login.dart';
import 'package:DigiDoc/screens/register.dart';
import 'pages/auth_page.dart';

enum Routes {
  auth,
  home,
  dossiers,
  dossier,
  capturePhoto,
  uploadDocument,
  infoConfirmation,
  login,
  register,
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: '/auth',
        name: Routes.auth.name,
        builder: (context, state) => AuthPage(),
      ),
      GoRoute(
        path: '/home',
        name: Routes.home.name,
        builder: (context, state) => MyHomePage(title: 'DigiDoc'),
      ),
      GoRoute(
        path: '/dossiers',
        name: Routes.dossiers.name,
        builder: (context, state) => DossiersScreen(),
      ),
      GoRoute(
        path: '/dossier/:id/:name',
        name: Routes.dossier.name,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final name = state.pathParameters['name']!;
          return DossierScreen(dossierId: id, dossierName: name);
        },
      ),
      GoRoute(
        path: '/capture-photo',
        name: Routes.capturePhoto.name,
        builder: (context, state) => CaptureDocumentPhotoScreen(),
      ),
      GoRoute(
        path: '/upload-document',
        name: Routes.uploadDocument.name,
        builder: (context, state) => UploadDocumentScreen(),
      ),
      GoRoute(
        path: '/info-confirmation',
        name: Routes.infoConfirmation.name,
        builder: (context, state) {
          final images = state.extra as List<XFile>? ?? [];
          return InfoConfirmationScreen(imagesList: images);
        },
      ),
      GoRoute(
        path: '/login',
        name: Routes.login.name,
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: Routes.register.name,
        builder: (context, state) => RegisterScreen(),
      ),
    ],
  );
});