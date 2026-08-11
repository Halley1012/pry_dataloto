import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

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
    Locale('pt'),
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

  /// No description provided for @descripcionBienvenida.
  ///
  /// In es, this message translates to:
  /// **'Estamos emocionados de ayudarte con predicciones inteligentes y hacer que disfrutes al máximo la emoción de cada sorteo.'**
  String get descripcionBienvenida;

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

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico'**
  String get email;

  /// No description provided for @contrasena.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get contrasena;

  /// No description provided for @olvidoContrasena.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidó la contraseña?'**
  String get olvidoContrasena;

  /// No description provided for @ingresar.
  ///
  /// In es, this message translates to:
  /// **'Ingresar'**
  String get ingresar;

  /// No description provided for @iniciaSesionParaContinuar.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para continuar'**
  String get iniciaSesionParaContinuar;

  /// No description provided for @nombre.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get nombre;

  /// No description provided for @crearCuenta.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get crearCuenta;

  /// No description provided for @notificaciones.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notificaciones;

  /// No description provided for @configuracion.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get configuracion;

  /// No description provided for @cerrarSesion.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get cerrarSesion;

  /// No description provided for @perfil.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get perfil;

  /// No description provided for @inicio.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get inicio;

  /// No description provided for @resultados.
  ///
  /// In es, this message translates to:
  /// **'Resultados'**
  String get resultados;

  /// No description provided for @misAnuncios.
  ///
  /// In es, this message translates to:
  /// **'Mis anuncios'**
  String get misAnuncios;

  /// No description provided for @metodosPago.
  ///
  /// In es, this message translates to:
  /// **'Métodos de pago'**
  String get metodosPago;

  /// No description provided for @invitarAmigos.
  ///
  /// In es, this message translates to:
  /// **'Invitar amigos'**
  String get invitarAmigos;

  /// No description provided for @ayudaSoporte.
  ///
  /// In es, this message translates to:
  /// **'Ayuda y soporte'**
  String get ayudaSoporte;

  /// No description provided for @eliminarCuenta.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get eliminarCuenta;

  /// No description provided for @pais.
  ///
  /// In es, this message translates to:
  /// **'País'**
  String get pais;

  /// No description provided for @departamentoEstado.
  ///
  /// In es, this message translates to:
  /// **'Departamento / Estado'**
  String get departamentoEstado;

  /// No description provided for @editarPerfil.
  ///
  /// In es, this message translates to:
  /// **'Editar Perfil'**
  String get editarPerfil;

  /// No description provided for @guardarCambios.
  ///
  /// In es, this message translates to:
  /// **'Guardar Cambios'**
  String get guardarCambios;

  /// No description provided for @miPais.
  ///
  /// In es, this message translates to:
  /// **'Mi País'**
  String get miPais;

  /// No description provided for @internacionales.
  ///
  /// In es, this message translates to:
  /// **'Internacionales'**
  String get internacionales;

  /// No description provided for @todas.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get todas;

  /// No description provided for @sinNotificaciones.
  ///
  /// In es, this message translates to:
  /// **'No tienes notificaciones aún'**
  String get sinNotificaciones;

  /// No description provided for @explorar.
  ///
  /// In es, this message translates to:
  /// **'Explorar'**
  String get explorar;

  /// No description provided for @buscarLoteria.
  ///
  /// In es, this message translates to:
  /// **'Buscar lotería...'**
  String get buscarLoteria;

  /// No description provided for @populares.
  ///
  /// In es, this message translates to:
  /// **'Populares'**
  String get populares;

  /// No description provided for @verTodas.
  ///
  /// In es, this message translates to:
  /// **'Ver todas'**
  String get verTodas;

  /// No description provided for @proximoSorteo.
  ///
  /// In es, this message translates to:
  /// **'Próximo sorteo'**
  String get proximoSorteo;

  /// No description provided for @todasLasLoterias.
  ///
  /// In es, this message translates to:
  /// **'Todas las loterías'**
  String get todasLasLoterias;

  /// No description provided for @comentarios.
  ///
  /// In es, this message translates to:
  /// **'Comentarios'**
  String get comentarios;

  /// No description provided for @responder.
  ///
  /// In es, this message translates to:
  /// **'Responder'**
  String get responder;

  /// No description provided for @respuesta.
  ///
  /// In es, this message translates to:
  /// **'respuesta'**
  String get respuesta;

  /// No description provided for @respuestas.
  ///
  /// In es, this message translates to:
  /// **'respuestas'**
  String get respuestas;

  /// No description provided for @sinPosts.
  ///
  /// In es, this message translates to:
  /// **'No hay posts aún'**
  String get sinPosts;

  /// No description provided for @anunciosDestacados.
  ///
  /// In es, this message translates to:
  /// **'Anuncios destacados'**
  String get anunciosDestacados;

  /// No description provided for @derechosReservados.
  ///
  /// In es, this message translates to:
  /// **'© 2025 DataLoto. Todos los derechos reservados.'**
  String get derechosReservados;

  /// No description provided for @version.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get version;

  /// No description provided for @sinNotificacionesCategoria.
  ///
  /// In es, this message translates to:
  /// **'Sin notificaciones en esta categoría'**
  String get sinNotificacionesCategoria;

  /// No description provided for @verTodasNotificaciones.
  ///
  /// In es, this message translates to:
  /// **'Ver todas las notificaciones'**
  String get verTodasNotificaciones;

  /// No description provided for @explorarLoterias.
  ///
  /// In es, this message translates to:
  /// **'Explorar Loterías'**
  String get explorarLoterias;

  /// No description provided for @buscarLoteriaOPais.
  ///
  /// In es, this message translates to:
  /// **'Buscar lotería o país...'**
  String get buscarLoteriaOPais;

  /// No description provided for @buscarPorLoteriaOPais.
  ///
  /// In es, this message translates to:
  /// **'Buscar por lotería o país...'**
  String get buscarPorLoteriaOPais;

  /// No description provided for @proximoSorteoConFecha.
  ///
  /// In es, this message translates to:
  /// **'Próximo sorteo:'**
  String get proximoSorteoConFecha;

  /// No description provided for @verTodasLoteriasMundo.
  ///
  /// In es, this message translates to:
  /// **'Ver todas las loterías del mundo'**
  String get verTodasLoteriasMundo;

  /// No description provided for @analisisYResultados.
  ///
  /// In es, this message translates to:
  /// **'Análisis y Resultados'**
  String get analisisYResultados;

  /// No description provided for @aunNoTienesJugadas.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes jugadas'**
  String get aunNoTienesJugadas;

  /// No description provided for @empiezaAGuardarNumeros.
  ///
  /// In es, this message translates to:
  /// **'Empieza a guardar tus números favoritos desde la sección Explorar.'**
  String get empiezaAGuardarNumeros;

  /// No description provided for @usuarioPremium.
  ///
  /// In es, this message translates to:
  /// **'Usuario Premium'**
  String get usuarioPremium;

  /// No description provided for @ganaBeneficios.
  ///
  /// In es, this message translates to:
  /// **'Gana beneficios'**
  String get ganaBeneficios;

  /// No description provided for @avisoLegal.
  ///
  /// In es, this message translates to:
  /// **'Aviso legal'**
  String get avisoLegal;

  /// No description provided for @acercaDe.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get acercaDe;

  /// No description provided for @cerrar.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get cerrar;

  /// No description provided for @contenidoAvisoLegal.
  ///
  /// In es, this message translates to:
  /// **'Esta app no es oficial ni está asociada con operadores de loterías ni con entidades reguladoras de juegos de azar en ningún país. No es un juego de lotería, sino una herramienta de análisis estadístico e inteligencia artificial que genera predicciones para que elijas tus números con más confianza. Los resultados no garantizan premios y su uso es únicamente con fines informativos y de entretenimiento.'**
  String get contenidoAvisoLegal;

  /// No description provided for @contenidoAcercaDe.
  ///
  /// In es, this message translates to:
  /// **'DataLoto utiliza inteligencia artificial para analizar patrones históricos de loterías y ofrecer predicciones informadas. Aunque nuestras predicciones se basan en datos, no hay certeza absoluta de que esos números sean los ganadores, ya que la lotería es un juego de azar. No garantizamos premios, solo te ayudamos a elegir con más confianza. Usa la app con responsabilidad y solo con fines de entretenimiento. La decisión de utilizar estas predicciones queda bajo tu propia responsabilidad.'**
  String get contenidoAcercaDe;

  /// No description provided for @notificacionesIA.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones IA'**
  String get notificacionesIA;

  /// No description provided for @marcarTodoComoLeido.
  ///
  /// In es, this message translates to:
  /// **'Marcar todo como leído'**
  String get marcarTodoComoLeido;

  /// No description provided for @seleccionarTodo.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todo'**
  String get seleccionarTodo;

  /// No description provided for @desmarcarTodo.
  ///
  /// In es, this message translates to:
  /// **'Desmarcar todo'**
  String get desmarcarTodo;

  /// No description provided for @eliminar.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get eliminar;

  /// No description provided for @imprimirPDF.
  ///
  /// In es, this message translates to:
  /// **'Imprimir PDF'**
  String get imprimirPDF;

  /// No description provided for @historialJugadas.
  ///
  /// In es, this message translates to:
  /// **'Historial de Jugadas'**
  String get historialJugadas;

  /// No description provided for @guardadasCantidad.
  ///
  /// In es, this message translates to:
  /// **'guardada(s)'**
  String get guardadasCantidad;

  /// No description provided for @noTienesJugadasGuardadas.
  ///
  /// In es, this message translates to:
  /// **'No tienes jugadas guardadas aún'**
  String get noTienesJugadasGuardadas;

  /// No description provided for @eliminarJugadas.
  ///
  /// In es, this message translates to:
  /// **'Eliminar jugadas'**
  String get eliminarJugadas;

  /// No description provided for @confirmarCerrarSesion.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas salir?'**
  String get confirmarCerrarSesion;

  /// No description provided for @idiomaSistema.
  ///
  /// In es, this message translates to:
  /// **'Idioma del Sistema'**
  String get idiomaSistema;

  /// No description provided for @seleccionarIdioma.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Idioma'**
  String get seleccionarIdioma;

  /// No description provided for @cancelar.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelar;
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
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

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
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
