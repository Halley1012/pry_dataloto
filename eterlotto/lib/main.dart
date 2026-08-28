import 'dart:async';
import 'package:eterlotto/screens/welcome.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'screens/registro.dart';
import 'screens/splash_screen.dart';
import 'screens/notifications_screen.dart';
import 'styles/colores.dart';
import 'styles/app_text_styles.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

import 'providers/locale_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/estadisticas_dashboard_screen.dart';
import 'screens/subscription_screen.dart';
import 'package:eterlotto/services/push_notification_service.dart';
import 'package:eterlotto/services/ad_service.dart';

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

      // Iniciar la aplicación inmediatamente (0 ms de pantalla negra)
      runApp(const EterlottoApp());

      // Inicializar Notificaciones Push y Firebase en segundo plano
      unawaited(PushNotificationService.initialize());

      // Inicializar Google Mobile Ads en segundo plano
      unawaited(AdService.instance.initialize());
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

class EterlottoApp extends StatelessWidget {
  const EterlottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: ListenableBuilder(
        listenable: localeProvider,
        builder: (context, _) {
          return MaterialApp(
          navigatorKey: navigatorKey, // 👈 importante para navegar globalmente
          debugShowCheckedModeBanner: false,
          initialRoute: '/splash',
          title: 'Eterlotto',
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
            textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
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
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1E1E24),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              labelStyle: GoogleFonts.montserrat(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              hintStyle: GoogleFonts.montserrat(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              floatingLabelStyle: GoogleFonts.montserrat(
                color: AppColors.yellow,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white12, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white12, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
            ),
          ),
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomeScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/subscription': (context) => const SubscriptionScreen(),
            '/registro': (context) => const RegistroScreen(),
          },
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            if (name == '/registro') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => RegistroScreen(
                  user: args?['user'] as Map<String, dynamic>?,
                  userId: args?['userId'] as int?,
                  isSocialOnboarding: args?['isSocialOnboarding'] as bool? ?? false,
                ),
              );
            }
            if (name.startsWith('/estadisticas_')) {
              final loteriaKey = name.replaceFirst('/estadisticas_', '');
              return MaterialPageRoute(
                builder: (_) => EstadisticasDashboardScreen(
                  loteriaNombreInicial: loteriaKey,
                  loteriaRoute: loteriaKey,
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
