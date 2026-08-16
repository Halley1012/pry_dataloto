import 'dart:async';
import 'package:dataloto/screens/welcome.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/loteria_screen.dart';
import 'screens/login.dart';
import 'screens/registro.dart';
import 'screens/splash_screen.dart';
import 'screens/notifications_screen.dart';
import 'styles/colores.dart';
import 'styles/app_text_styles.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

import 'providers/locale_provider.dart';
import 'providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'screens/estadisticas_dashboard_screen.dart';
import 'package:dataloto/services/push_notification_service.dart';

// 🔑 Navigator key global y Provider de Idioma global
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final LocaleProvider localeProvider = LocaleProvider();

void main() {
  runZonedGuarded(
    () async {
      // Inicializar bindings y configuraciones dentro de la misma zona
      WidgetsFlutterBinding.ensureInitialized();

      // 🔥 Inicializar Notificaciones Push y Firebase
      await PushNotificationService.initialize();

      // Bloquear la app en vertical
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Iniciar la aplicación
      runApp(const DataLotoApp());
    },
    (error, stack) {
      debugPrint("❌ Error capturado en runZonedGuarded: $error");
      if (error.toString().contains("401") ||
          error.toString().contains("Token inválido")) {
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: ListenableBuilder(
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
            Locale('pt', ''), // Portugués
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (localeProvider.locale != null) {
              return localeProvider.locale;
            }
            if (deviceLocale != null) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == deviceLocale.languageCode) {
                  return supportedLocale;
                }
              }
            }
            return supportedLocales.first; // Default fallback: Español
          },
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
            '/home': (context) => HomeScreen(),
            '/notifications': (context) => const NotificationsScreen(),
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
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            if (name.startsWith('/estadisticas_')) {
              final loteriaKey = name.replaceFirst('/estadisticas_', '');
              return MaterialPageRoute(
                builder: (_) => EstadisticasDashboardScreen(
                  loteriaNombreInicial: loteriaKey,
                  loteriaRoute: loteriaKey,
                ),
              );
            }
            if (name.startsWith('/')) {
              final cleanName = name.substring(1);
              final args = settings.arguments;
              return MaterialPageRoute(
                builder: (_) => LoteriaScreen(
                  loteriaNombre: cleanName,
                  loteriaRoute: cleanName,
                  loteriaData: args is Map<String, dynamic> ? args : null,
                ),
              );
            }
            return null;
          },
        );
      },
    ),
    );
  }
}
