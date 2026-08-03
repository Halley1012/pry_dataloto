import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @tituloApp.
  ///
  /// In es, this message translates to:
  /// **'DataLoto'**
  String get tituloApp;

  /// No description provided for @iniciarSesion.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get iniciarSesion;

  /// No description provided for @registrarse.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get registrarse;

  /// No description provided for @bienvenido.
  ///
  /// In es, this message translates to:
  /// **'¡Bienvenido a DataLoto!'**
  String get bienvenido;

  /// No description provided for @prediccionesInteligentes.
  ///
  /// In es, this message translates to:
  /// **'Predicciones Inteligentes'**
  String get prediccionesInteligentes;

  /// No description provided for @ultimosResultados.
  ///
  /// In es, this message translates to:
  /// **'Últimos 5 resultados'**
  String get ultimosResultados;

  /// No description provided for @ultimosResultadosBaloto.
  ///
  /// In es, this message translates to:
  /// **'Últimos 5 resultados Baloto'**
  String get ultimosResultadosBaloto;

  /// No description provided for @ultimosResultadosRevancha.
  ///
  /// In es, this message translates to:
  /// **'Últimos 5 resultados Baloto Revancha'**
  String get ultimosResultadosRevancha;

  /// No description provided for @tusNumerosSuerte.
  ///
  /// In es, this message translates to:
  /// **'Tus números de la suerte'**
  String get tusNumerosSuerte;

  /// No description provided for @generar.
  ///
  /// In es, this message translates to:
  /// **'Generar'**
  String get generar;

  /// No description provided for @guardar.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get guardar;

  /// No description provided for @misJugadas.
  ///
  /// In es, this message translates to:
  /// **'Mis jugadas'**
  String get misJugadas;

  /// No description provided for @estadisticas.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get estadisticas;

  /// No description provided for @estadisticasAvanzadas.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas Avanzadas y Gráficas'**
  String get estadisticasAvanzadas;

  /// No description provided for @seleccionaNumeros.
  ///
  /// In es, this message translates to:
  /// **'Selecciona tus números'**
  String get seleccionaNumeros;

  /// No description provided for @sorteosEvaluados.
  ///
  /// In es, this message translates to:
  /// **'Sorteos Evaluados'**
  String get sorteosEvaluados;

  /// No description provided for @numerosCalientes.
  ///
  /// In es, this message translates to:
  /// **'Números Calientes'**
  String get numerosCalientes;

  /// No description provided for @numerosFrios.
  ///
  /// In es, this message translates to:
  /// **'Números Fríos'**
  String get numerosFrios;

  /// No description provided for @frecuenciaHistorica.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia Histórica'**
  String get frecuenciaHistorica;

  /// No description provided for @ausenciaSorteos.
  ///
  /// In es, this message translates to:
  /// **'Días / Sorteos Sin Salir'**
  String get ausenciaSorteos;

  /// No description provided for @parImpar.
  ///
  /// In es, this message translates to:
  /// **'Distribución Par vs Impar'**
  String get parImpar;

  /// No description provided for @bajosAltos.
  ///
  /// In es, this message translates to:
  /// **'Bajos vs Altos'**
  String get bajosAltos;

  /// No description provided for @sumaCombinacion.
  ///
  /// In es, this message translates to:
  /// **'Suma de la Combinación'**
  String get sumaCombinacion;

  /// No description provided for @parejasFrecuentes.
  ///
  /// In es, this message translates to:
  /// **'Parejas Más Frecuentes'**
  String get parejasFrecuentes;

  /// No description provided for @scoreProbabilidadIA.
  ///
  /// In es, this message translates to:
  /// **'Score de Probabilidad IA'**
  String get scoreProbabilidadIA;

  /// No description provided for @comparacionIA.
  ///
  /// In es, this message translates to:
  /// **'Comportamiento Histórico vs IA'**
  String get comparacionIA;

  /// No description provided for @idioma.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get idioma;

  /// No description provided for @cambiarIdioma.
  ///
  /// In es, this message translates to:
  /// **'Cambiar Idioma'**
  String get cambiarIdioma;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
