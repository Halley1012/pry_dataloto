import 'dart:async';
import 'package:dataloto/screens/welcome.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/baloto.dart';
import 'screens/miloto.dart';
import 'screens/login.dart';
import 'screens/color_loto.dart';
import 'screens/registro.dart';
import 'screens/splash_screen.dart';
import 'styles/colores.dart';
import 'styles/app_text_styles.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

import 'providers/locale_provider.dart';
import 'screens/estadisticas_bloto.dart';
import 'screens/estadisticas_mloto.dart';

// 🔑 Navigator key global y Provider de Idioma global
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final LocaleProvider localeProvider = LocaleProvider();

void main() {
  runZonedGuarded(
    () async {
      // Inicializar bindings y configuraciones dentro de la misma zona
      WidgetsFlutterBinding.ensureInitialized();

      // Bloquear la app en vertical
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Iniciar la aplicación
      runApp(const DataLotoApp());
    },
    (error, stack) {
      if (error.toString().contains("invalid token")) {
        // Si el token está inválido → limpiar stack y mandar a Login
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } else {
        debugPrint("🔥 Error no controlado: $error");
      }
    },
  );
}

class DataLotoApp extends StatelessWidget {
  const DataLotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeProvider,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey, // 👈 importante para navegar globalmente
          debugShowCheckedModeBanner: false,
          initialRoute: '/splash',
          title: 'DataLoto',
          locale: localeProvider.locale,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', ''), // Español
            Locale('en', ''), // Inglés
          ],
          theme: ThemeData.dark().copyWith(
            primaryColor: Colors.deepPurple,
            scaffoldBackgroundColor: AppColors.blackfondo,
            canvasColor: AppColors.blackfondo,
            cardColor: AppColors.darkGray,
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurple,
              surface: AppColors.blackfondo,
            ),
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.amber,
              contentTextStyle: AppTextStyles.mensajeImportante.copyWith(
                color: const Color(0xFF1E1E1E),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginPage(),
            '/baloto': (context) => const BalotoScreen(),
            '/miloto': (context) => const MilotoScreen(),
            '/color_loto': (context) => ColorLotoScreen(),
            '/estadisticas_bloto': (context) => const EstadisticasBlotoScreen(),
            '/estadisticas_mloto': (context) => const EstadisticasMlotoScreen(),
            '/home': (context) => HomeScreen(),
            '/registro': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;

              // Si no se pasan argumentos, usar valores por defecto
              if (args == null || args is! Map<String, dynamic>) {
                return const RegistroScreen(user: null, userId: null);
              }

              return RegistroScreen(
                user: args['user'] as Map<String, dynamic>?,
                userId: args['userId'] as int?,
              );
            },
          },
        );
      },
    );
  }
}
