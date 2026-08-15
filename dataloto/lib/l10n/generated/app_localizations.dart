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
  /// **'Días / Sorteios Sin Salir'**
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
  /// **'Sin notificaciones para tu país'**
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
  /// **'Notificaciones'**
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

  /// No description provided for @jackpotEstimado.
  ///
  /// In es, this message translates to:
  /// **'Jackpot estimado'**
  String get jackpotEstimado;

  /// No description provided for @millonesCOP.
  ///
  /// In es, this message translates to:
  /// **'millones COP'**
  String get millonesCOP;

  /// No description provided for @millonesUSD.
  ///
  /// In es, this message translates to:
  /// **'millones USD'**
  String get millonesUSD;

  /// No description provided for @resumenRapido.
  ///
  /// In es, this message translates to:
  /// **'Resumen rápido'**
  String get resumenRapido;

  /// No description provided for @verEstadisticasCompletas.
  ///
  /// In es, this message translates to:
  /// **'Ver estadísticas completas ›'**
  String get verEstadisticasCompletas;

  /// No description provided for @masCaliente.
  ///
  /// In es, this message translates to:
  /// **'Más caliente'**
  String get masCaliente;

  /// No description provided for @masFrio.
  ///
  /// In es, this message translates to:
  /// **'Más frío'**
  String get masFrio;

  /// No description provided for @prediccionIAHoy.
  ///
  /// In es, this message translates to:
  /// **'Predicción IA para hoy'**
  String get prediccionIAHoy;

  /// No description provided for @basadaEnAnalisisDe.
  ///
  /// In es, this message translates to:
  /// **'Basada en análisis de {count} sorteos'**
  String basadaEnAnalisisDe(int count);

  /// No description provided for @indiceAfinidadHistorica.
  ///
  /// In es, this message translates to:
  /// **'Índice de afinidad histórica'**
  String get indiceAfinidadHistorica;

  /// No description provided for @tuJugadaSeleccionada.
  ///
  /// In es, this message translates to:
  /// **'Tu Jugada Seleccionada'**
  String get tuJugadaSeleccionada;

  /// No description provided for @balotasPrincipales.
  ///
  /// In es, this message translates to:
  /// **'{count} balotas principales'**
  String balotasPrincipales(int count);

  /// No description provided for @balotaRoja.
  ///
  /// In es, this message translates to:
  /// **'1 balota roja'**
  String get balotaRoja;

  /// No description provided for @tocaNumerosModificar.
  ///
  /// In es, this message translates to:
  /// **'Toca los números abajo para modificar'**
  String get tocaNumerosModificar;

  /// No description provided for @numeroSuerteSugerido.
  ///
  /// In es, this message translates to:
  /// **'Número de la suerte sugerido por IA'**
  String get numeroSuerteSugerido;

  /// No description provided for @jugada.
  ///
  /// In es, this message translates to:
  /// **'Jugada'**
  String get jugada;

  /// No description provided for @notaTendenciasEstadisticas.
  ///
  /// In es, this message translates to:
  /// **'Nota: son solo tendencias estadísticas, no garantías absolutas.'**
  String get notaTendenciasEstadisticas;

  /// No description provided for @generarJugada.
  ///
  /// In es, this message translates to:
  /// **'Generar Jugada'**
  String get generarJugada;

  /// No description provided for @guardarJugada.
  ///
  /// In es, this message translates to:
  /// **'Guardar Jugada'**
  String get guardarJugada;

  /// No description provided for @guardando.
  ///
  /// In es, this message translates to:
  /// **'Guardando...'**
  String get guardando;

  /// No description provided for @jugadaGuardadaExito.
  ///
  /// In es, this message translates to:
  /// **'¡Jugada guardada con éxito! 🎉'**
  String get jugadaGuardadaExito;

  /// No description provided for @errorGuardarJugada.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar la jugada'**
  String get errorGuardarJugada;

  /// No description provided for @cargandoPrediccion.
  ///
  /// In es, this message translates to:
  /// **'Cargando predicción... Intenta de nuevo'**
  String get cargandoPrediccion;

  /// No description provided for @debesSeleccionarBalotas.
  ///
  /// In es, this message translates to:
  /// **'Debes seleccionar 5 balotas principales y 1 balota roja para guardar tu jugada.'**
  String get debesSeleccionarBalotas;

  /// No description provided for @jugadaYaExiste.
  ///
  /// In es, this message translates to:
  /// **'Esta jugada ya se encuentra en tus jugadas guardadas'**
  String get jugadaYaExiste;

  /// No description provided for @balotasRojas.
  ///
  /// In es, this message translates to:
  /// **'Balotas Rojas'**
  String get balotasRojas;

  /// No description provided for @numerosOrdenadosProbabilidad.
  ///
  /// In es, this message translates to:
  /// **'Números ordenados de mayor a menor probabilidad.'**
  String get numerosOrdenadosProbabilidad;

  /// No description provided for @tocaNumeroSeleccionar.
  ///
  /// In es, this message translates to:
  /// **'Toca un número para seleccionarlo'**
  String get tocaNumeroSeleccionar;

  /// No description provided for @ultimoSorteo.
  ///
  /// In es, this message translates to:
  /// **'Último sorteo'**
  String get ultimoSorteo;

  /// No description provided for @sinNumeros.
  ///
  /// In es, this message translates to:
  /// **'Sin números'**
  String get sinNumeros;

  /// No description provided for @noticiasAlertas.
  ///
  /// In es, this message translates to:
  /// **'Noticias / Alertas'**
  String get noticiasAlertas;

  /// No description provided for @hoyEsSorteo.
  ///
  /// In es, this message translates to:
  /// **'Hoy es el sorteo de {loteria}'**
  String hoyEsSorteo(String loteria);

  /// No description provided for @noOlvidesRevisar.
  ///
  /// In es, this message translates to:
  /// **'No olvides revisar tus números y mucha suerte.'**
  String get noOlvidesRevisar;

  /// No description provided for @paresImpares.
  ///
  /// In es, this message translates to:
  /// **'Pares - Impares'**
  String get paresImpares;

  /// No description provided for @analizados.
  ///
  /// In es, this message translates to:
  /// **'Analizados'**
  String get analizados;

  /// No description provided for @veces.
  ///
  /// In es, this message translates to:
  /// **'veces'**
  String get veces;

  /// No description provided for @versionApp.
  ///
  /// In es, this message translates to:
  /// **'Versión de la app'**
  String get versionApp;

  /// No description provided for @tocaParaVerMas.
  ///
  /// In es, this message translates to:
  /// **'Toca para ver más'**
  String get tocaParaVerMas;

  /// No description provided for @filtrosAnalisis.
  ///
  /// In es, this message translates to:
  /// **'Filtros de Análisis'**
  String get filtrosAnalisis;

  /// No description provided for @sorteos.
  ///
  /// In es, this message translates to:
  /// **'Sorteos'**
  String get sorteos;

  /// No description provided for @tipo.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get tipo;

  /// No description provided for @numerosCalientesFrios.
  ///
  /// In es, this message translates to:
  /// **'Números Calientes y Fríos 🔥❄️'**
  String get numerosCalientesFrios;

  /// No description provided for @masFrecuentes.
  ///
  /// In es, this message translates to:
  /// **'Más Frecuentes'**
  String get masFrecuentes;

  /// No description provided for @menosFrecuentes.
  ///
  /// In es, this message translates to:
  /// **'Menos Frecuentes'**
  String get menosFrecuentes;

  /// No description provided for @ausenciaSorteosTitle.
  ///
  /// In es, this message translates to:
  /// **'Días / Sorteos Sin Salir (Ausencia)'**
  String get ausenciaSorteosTitle;

  /// No description provided for @balotasMayorTiempo.
  ///
  /// In es, this message translates to:
  /// **'Balotas con mayor tiempo sin aparecer:'**
  String get balotasMayorTiempo;

  /// No description provided for @apariciones.
  ///
  /// In es, this message translates to:
  /// **'apariciones'**
  String get apariciones;

  /// No description provided for @pareja.
  ///
  /// In es, this message translates to:
  /// **'Pareja'**
  String get pareja;

  /// No description provided for @altaConsistenciaIA.
  ///
  /// In es, this message translates to:
  /// **'✅ Alta consistencia con patrones históricos par/impar y dispersión de suma.'**
  String get altaConsistenciaIA;

  /// No description provided for @comportamientoHistoricoVsIA.
  ///
  /// In es, this message translates to:
  /// **'Comportamiento Histórico vs IA ⚡'**
  String get comportamientoHistoricoVsIA;

  /// No description provided for @numerosMayorTendencia.
  ///
  /// In es, this message translates to:
  /// **'Números de mayor tendencia histórica:'**
  String get numerosMayorTendencia;

  /// No description provided for @prediccionActualIA.
  ///
  /// In es, this message translates to:
  /// **'Predicción actual del modelo IA:'**
  String get prediccionActualIA;

  /// No description provided for @coberturaIA.
  ///
  /// In es, this message translates to:
  /// **'Cobertura IA'**
  String get coberturaIA;

  /// No description provided for @verTodasNotificacionesButton.
  ///
  /// In es, this message translates to:
  /// **'Ver todas las notificaciones'**
  String get verTodasNotificacionesButton;

  /// No description provided for @sinNotificacionesAun.
  ///
  /// In es, this message translates to:
  /// **'No tienes notificaciones aún'**
  String get sinNotificacionesAun;

  /// No description provided for @miPaisFilter.
  ///
  /// In es, this message translates to:
  /// **'Mi País'**
  String get miPaisFilter;

  /// No description provided for @internacionalesFilter.
  ///
  /// In es, this message translates to:
  /// **'Internacionales'**
  String get internacionalesFilter;

  /// No description provided for @todasFilter.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get todasFilter;

  /// No description provided for @marcarLeido.
  ///
  /// In es, this message translates to:
  /// **'Marcar como leído'**
  String get marcarLeido;

  /// No description provided for @errorConexion.
  ///
  /// In es, this message translates to:
  /// **'Error de conexión'**
  String get errorConexion;

  /// No description provided for @credencialesInvalidas.
  ///
  /// In es, this message translates to:
  /// **'Credenciales inválidas'**
  String get credencialesInvalidas;

  /// No description provided for @errorObtenerTokens.
  ///
  /// In es, this message translates to:
  /// **'Error al obtener tokens'**
  String get errorObtenerTokens;

  /// No description provided for @ingresaEmailContrasena.
  ///
  /// In es, this message translates to:
  /// **'⚠️ Ingresa email y contraseña'**
  String get ingresaEmailContrasena;

  /// No description provided for @enviadoEnlace.
  ///
  /// In es, this message translates to:
  /// **'Se ha enviado un enlace a {email}'**
  String enviadoEnlace(String email);

  /// No description provided for @recuperarContrasena.
  ///
  /// In es, this message translates to:
  /// **'Recuperar Contraseña'**
  String get recuperarContrasena;

  /// No description provided for @cancelarButton.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelarButton;

  /// No description provided for @enviarButton.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get enviarButton;

  /// No description provided for @noDisponible.
  ///
  /// In es, this message translates to:
  /// **'No disponible por el momento...'**
  String get noDisponible;

  /// No description provided for @estadisticasLoteria.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas {loteria}'**
  String estadisticasLoteria(String loteria);

  /// No description provided for @rangoBalotas.
  ///
  /// In es, this message translates to:
  /// **'Rango Balotas'**
  String get rangoBalotas;

  /// No description provided for @powerballRoja.
  ///
  /// In es, this message translates to:
  /// **'Powerball Roja'**
  String get powerballRoja;

  /// No description provided for @starBall.
  ///
  /// In es, this message translates to:
  /// **'Star Ball'**
  String get starBall;

  /// No description provided for @megaBall.
  ///
  /// In es, this message translates to:
  /// **'Mega Ball'**
  String get megaBall;

  /// No description provided for @cashBall.
  ///
  /// In es, this message translates to:
  /// **'Cash Ball'**
  String get cashBall;

  /// No description provided for @errorCargarEstadisticas.
  ///
  /// In es, this message translates to:
  /// **'No fue posible conectar con el servidor para obtener las estadísticas.'**
  String get errorCargarEstadisticas;

  /// No description provided for @promedioSumaHistorica.
  ///
  /// In es, this message translates to:
  /// **'Promedio de suma histórica: {valor}'**
  String promedioSumaHistorica(String valor);

  /// No description provided for @coberturaResultado.
  ///
  /// In es, this message translates to:
  /// **'Cobertura del resultado'**
  String get coberturaResultado;

  /// No description provided for @numerosEnTopIA.
  ///
  /// In es, this message translates to:
  /// **'Números en el Top {count} de la IA'**
  String numerosEnTopIA(int count);

  /// No description provided for @hitsDeAciertos.
  ///
  /// In es, this message translates to:
  /// **'{hits} de {total} aciertos'**
  String hitsDeAciertos(int hits, int total);

  /// No description provided for @excelenteResultado.
  ///
  /// In es, this message translates to:
  /// **'¡Excelente resultado! 🎯'**
  String get excelenteResultado;

  /// No description provided for @buenDesempeno.
  ///
  /// In es, this message translates to:
  /// **'Buen desempeño 📊'**
  String get buenDesempeno;

  /// No description provided for @insightsIA.
  ///
  /// In es, this message translates to:
  /// **'Insights IA'**
  String get insightsIA;

  /// No description provided for @resultadoReal.
  ///
  /// In es, this message translates to:
  /// **'Resultado real'**
  String get resultadoReal;

  /// No description provided for @tendenciasIA.
  ///
  /// In es, this message translates to:
  /// **'Tendencias IA'**
  String get tendenciasIA;

  /// No description provided for @noHayTendencias.
  ///
  /// In es, this message translates to:
  /// **'No hay tendencias detalladas guardadas para este sorteo.'**
  String get noHayTendencias;

  /// No description provided for @sorteoDel.
  ///
  /// In es, this message translates to:
  /// **'Sorteo del {fecha}'**
  String sorteoDel(String fecha);

  /// No description provided for @revancha.
  ///
  /// In es, this message translates to:
  /// **'Revancha'**
  String get revancha;

  /// No description provided for @ultimos5ResultadosNombre.
  ///
  /// In es, this message translates to:
  /// **'Últimos 5 resultados {nombre}'**
  String ultimos5ResultadosNombre(Object nombre);

  /// No description provided for @ultimosSorteos.
  ///
  /// In es, this message translates to:
  /// **'Últimos sorteos'**
  String get ultimosSorteos;

  /// No description provided for @reciente.
  ///
  /// In es, this message translates to:
  /// **'Reciente'**
  String get reciente;

  /// No description provided for @prediccionesNoDisponibles.
  ///
  /// In es, this message translates to:
  /// **'Las predicciones de la IA para este sorteo pasado no están disponibles en el historial.'**
  String get prediccionesNoDisponibles;

  /// No description provided for @insightIACayeron.
  ///
  /// In es, this message translates to:
  /// **'De los {count} números con mayor probabilidad generados por la IA para {loteria}, cayeron {hits}.'**
  String insightIACayeron(int count, String loteria, String hits);

  /// No description provided for @insightIANoCoincidencias.
  ///
  /// In es, this message translates to:
  /// **'De los {count} números con mayor probabilidad generados por la IA para {loteria}, no hubo coincidencias en este sorteo.'**
  String insightIANoCoincidencias(int count, String loteria);

  /// No description provided for @insightIACayeronDual.
  ///
  /// In es, this message translates to:
  /// **'De los {count} números con mayor probabilidad generados por la IA para {loteria}, cayeron {bText} y {rText}.'**
  String insightIACayeronDual(
    int count,
    String loteria,
    String bText,
    String rText,
  );

  /// No description provided for @aciertoIA.
  ///
  /// In es, this message translates to:
  /// **'Acierto IA'**
  String get aciertoIA;

  /// No description provided for @balotasPrincipalesTitle.
  ///
  /// In es, this message translates to:
  /// **'Balotas Principales'**
  String get balotasPrincipalesTitle;

  /// No description provided for @balotasRojasEspeciales.
  ///
  /// In es, this message translates to:
  /// **'Balotas Rojas / Especiales'**
  String get balotasRojasEspeciales;

  /// No description provided for @resultadosLoteria.
  ///
  /// In es, this message translates to:
  /// **'Resultados - {loteria}'**
  String resultadosLoteria(String loteria);

  /// No description provided for @sorteoFechaLabel.
  ///
  /// In es, this message translates to:
  /// **'Sorteo: {fecha}'**
  String sorteoFechaLabel(String fecha);

  /// No description provided for @numerosGanadores.
  ///
  /// In es, this message translates to:
  /// **'Números ganadores'**
  String get numerosGanadores;

  /// No description provided for @comparacionJugadas.
  ///
  /// In es, this message translates to:
  /// **'Comparación Mis Jugadas vs Resultado'**
  String get comparacionJugadas;

  /// No description provided for @aciertosLabel.
  ///
  /// In es, this message translates to:
  /// **'Aciertos'**
  String get aciertosLabel;

  /// No description provided for @balotaLabel.
  ///
  /// In es, this message translates to:
  /// **'Balota'**
  String get balotaLabel;

  /// No description provided for @sinAciertoLabel.
  ///
  /// In es, this message translates to:
  /// **'Sin acierto'**
  String get sinAciertoLabel;

  /// No description provided for @tusJugadasVsGanadores.
  ///
  /// In es, this message translates to:
  /// **'Tus jugadas guardadas vs Números ganadores del sorteo'**
  String get tusJugadasVsGanadores;

  /// No description provided for @noRealizasteJugadas.
  ///
  /// In es, this message translates to:
  /// **'No realizaste jugadas para este sorteo.'**
  String get noRealizasteJugadas;

  /// No description provided for @cantidadAciertos.
  ///
  /// In es, this message translates to:
  /// **'{count} acierto(s)'**
  String cantidadAciertos(int count);

  /// No description provided for @fechaLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get fechaLabel;

  /// No description provided for @aciertosSimple.
  ///
  /// In es, this message translates to:
  /// **'Aciertos'**
  String get aciertosSimple;

  /// No description provided for @coberturaIndividualDetalle.
  ///
  /// In es, this message translates to:
  /// **'{hits} de {total} números ganadores están en los {top} más probables'**
  String coberturaIndividualDetalle(int hits, int total, int top);

  /// No description provided for @nEnBaloto.
  ///
  /// In es, this message translates to:
  /// **'{count} en Baloto ({nums})'**
  String nEnBaloto(Object count, Object nums);

  /// No description provided for @ceroEnBaloto.
  ///
  /// In es, this message translates to:
  /// **'0 en Baloto'**
  String get ceroEnBaloto;

  /// No description provided for @nEnRevancha.
  ///
  /// In es, this message translates to:
  /// **'{count} en Revancha ({nums})'**
  String nEnRevancha(Object count, Object nums);

  /// No description provided for @ceroEnRevancha.
  ///
  /// In es, this message translates to:
  /// **'0 en Revancha'**
  String get ceroEnRevancha;

  /// No description provided for @nNumeros.
  ///
  /// In es, this message translates to:
  /// **'{count} números'**
  String nNumeros(int count);

  /// No description provided for @errorEnviarCorreo.
  ///
  /// In es, this message translates to:
  /// **'Error: No se pudo enviar el correo'**
  String get errorEnviarCorreo;

  /// No description provided for @usuarioRequerido.
  ///
  /// In es, this message translates to:
  /// **'Usuario requerido'**
  String get usuarioRequerido;

  /// No description provided for @correoInvalido.
  ///
  /// In es, this message translates to:
  /// **'Correo inválido'**
  String get correoInvalido;

  /// No description provided for @contrasenaMinima.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get contrasenaMinima;

  /// No description provided for @seleccionaPais.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un país'**
  String get seleccionaPais;

  /// No description provided for @seleccionaDepartamento.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un departamento'**
  String get seleccionaDepartamento;

  /// No description provided for @yaTienesCuenta.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? Inicia sesión'**
  String get yaTienesCuenta;

  /// No description provided for @actualizaTusDatos.
  ///
  /// In es, this message translates to:
  /// **'Actualiza tus datos'**
  String get actualizaTusDatos;

  /// No description provided for @registroUsuario.
  ///
  /// In es, this message translates to:
  /// **'Registro de usuario'**
  String get registroUsuario;

  /// No description provided for @modificaInformacion.
  ///
  /// In es, this message translates to:
  /// **'Modifica tu información'**
  String get modificaInformacion;

  /// No description provided for @confirmarEliminarCuenta.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar tu cuenta? Esta acción es irreversible.'**
  String get confirmarEliminarCuenta;

  /// No description provided for @error.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @sinResultadosAnalisis.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes análisis de resultados'**
  String get sinResultadosAnalisis;

  /// No description provided for @buscaloAqui.
  ///
  /// In es, this message translates to:
  /// **'Búscalo Aquí'**
  String get buscaloAqui;

  /// No description provided for @anunciateHoy.
  ///
  /// In es, this message translates to:
  /// **'¡Anúnciate hoy y haz que todos te conozcan!'**
  String get anunciateHoy;

  /// No description provided for @crearNuevaPublicidad.
  ///
  /// In es, this message translates to:
  /// **'Crear nueva publicidad'**
  String get crearNuevaPublicidad;

  /// No description provided for @buscarPorTitulo.
  ///
  /// In es, this message translates to:
  /// **'Buscar por título'**
  String get buscarPorTitulo;

  /// No description provided for @noHayAnunciosFiltros.
  ///
  /// In es, this message translates to:
  /// **'No hay anuncios disponibles \npara los filtros seleccionados.'**
  String get noHayAnunciosFiltros;

  /// No description provided for @todos.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get todos;

  /// No description provided for @todasCategorias.
  ///
  /// In es, this message translates to:
  /// **'Todas las categorías'**
  String get todasCategorias;

  /// No description provided for @noHayPaisesDisponibles.
  ///
  /// In es, this message translates to:
  /// **'No hay países disponibles'**
  String get noHayPaisesDisponibles;

  /// No description provided for @noHayDepartamentosDisponibles.
  ///
  /// In es, this message translates to:
  /// **'No hay departamentos disponibles'**
  String get noHayDepartamentosDisponibles;

  /// No description provided for @noHayCategoriasDisponibles.
  ///
  /// In es, this message translates to:
  /// **'No hay categorías disponibles'**
  String get noHayCategoriasDisponibles;

  /// No description provided for @estadoProvincia.
  ///
  /// In es, this message translates to:
  /// **'Estado / Provincia'**
  String get estadoProvincia;

  /// No description provided for @categoria.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get categoria;

  /// No description provided for @presionaOtraVezSalir.
  ///
  /// In es, this message translates to:
  /// **'Presiona otra vez para salir'**
  String get presionaOtraVezSalir;

  /// No description provided for @tusJugadasHoy.
  ///
  /// In es, this message translates to:
  /// **'Tus jugadas para hoy'**
  String get tusJugadasHoy;

  /// No description provided for @errorCargarJugadas.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar jugadas'**
  String get errorCargarJugadas;

  /// No description provided for @errorAgregarJugada.
  ///
  /// In es, this message translates to:
  /// **'Error al agregar jugada'**
  String get errorAgregarJugada;

  /// No description provided for @nro.
  ///
  /// In es, this message translates to:
  /// **'Nro.'**
  String get nro;

  /// No description provided for @totalLabel.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @misAnunciosTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis Anuncios'**
  String get misAnunciosTitle;

  /// No description provided for @noHasPublicadoAnuncios.
  ///
  /// In es, this message translates to:
  /// **'No has publicado ningún anuncio todavía.\n¡Crea el primero ahora!'**
  String get noHasPublicadoAnuncios;

  /// No description provided for @eliminarAnuncio.
  ///
  /// In es, this message translates to:
  /// **'Eliminar anuncio'**
  String get eliminarAnuncio;

  /// No description provided for @confirmarEliminarAnuncio.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de eliminar este anuncio?'**
  String get confirmarEliminarAnuncio;

  /// No description provided for @editar.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get editar;

  /// No description provided for @crearPublicidad.
  ///
  /// In es, this message translates to:
  /// **'Crear Publicidad'**
  String get crearPublicidad;

  /// No description provided for @editarAnuncio.
  ///
  /// In es, this message translates to:
  /// **'Editar Anuncio'**
  String get editarAnuncio;

  /// No description provided for @crearNuevoAnuncio.
  ///
  /// In es, this message translates to:
  /// **'Crear nuevo anuncio'**
  String get crearNuevoAnuncio;

  /// No description provided for @promocionaNegocioStyle.
  ///
  /// In es, this message translates to:
  /// **'Promociona tu negocio con estilo'**
  String get promocionaNegocioStyle;

  /// No description provided for @titulo.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get titulo;

  /// No description provided for @descripcion.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get descripcion;

  /// No description provided for @descripcionObligatoria.
  ///
  /// In es, this message translates to:
  /// **'Descripción obligatoria'**
  String get descripcionObligatoria;

  /// No description provided for @telefono.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get telefono;

  /// No description provided for @telefonoObligatorio.
  ///
  /// In es, this message translates to:
  /// **'Teléfono obligatorio'**
  String get telefonoObligatorio;

  /// No description provided for @direccion.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get direccion;

  /// No description provided for @imagenUrl.
  ///
  /// In es, this message translates to:
  /// **'Imagen URL'**
  String get imagenUrl;

  /// No description provided for @ciudad.
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get ciudad;

  /// No description provided for @redesSociales.
  ///
  /// In es, this message translates to:
  /// **'Redes sociales'**
  String get redesSociales;

  /// No description provided for @paginaWeb.
  ///
  /// In es, this message translates to:
  /// **'Página Web'**
  String get paginaWeb;

  /// No description provided for @whatsappObligatorio.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp obligatorio'**
  String get whatsappObligatorio;

  /// No description provided for @anuncioActualizado.
  ///
  /// In es, this message translates to:
  /// **'Anuncio actualizado'**
  String get anuncioActualizado;

  /// No description provided for @anuncioCreado.
  ///
  /// In es, this message translates to:
  /// **'Anuncio creado'**
  String get anuncioCreado;

  /// No description provided for @errorGuardar.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar'**
  String get errorGuardar;

  /// No description provided for @campoRequerido.
  ///
  /// In es, this message translates to:
  /// **'{campo} requerido'**
  String campoRequerido(String campo);

  /// No description provided for @seleccionaCampo.
  ///
  /// In es, this message translates to:
  /// **'Selecciona {campo}'**
  String seleccionaCampo(String campo);

  /// No description provided for @misJugadasLoteria.
  ///
  /// In es, this message translates to:
  /// **'Mis Jugadas de {loteria} - DataLoto'**
  String misJugadasLoteria(String loteria);

  /// No description provided for @noHayJugadasCompartir.
  ///
  /// In es, this message translates to:
  /// **'No hay jugadas para compartir'**
  String get noHayJugadasCompartir;

  /// No description provided for @buenaSuerteDataLoto.
  ///
  /// In es, this message translates to:
  /// **'¡Buena suerte con DataLoto!'**
  String get buenaSuerteDataLoto;

  /// No description provided for @tiqueteDataloto.
  ///
  /// In es, this message translates to:
  /// **'DATALOTO - TICKET {loteria}'**
  String tiqueteDataloto(String loteria);

  /// No description provided for @reporteJugadasGuardadas.
  ///
  /// In es, this message translates to:
  /// **'Reporte de Jugadas Guardadas ({count} jugada(s))'**
  String reporteJugadasGuardadas(int count);

  /// No description provided for @fechaGuardado.
  ///
  /// In es, this message translates to:
  /// **'Fecha Guardado'**
  String get fechaGuardado;

  /// No description provided for @balotasLoteria.
  ///
  /// In es, this message translates to:
  /// **'Balotas {loteria}'**
  String balotasLoteria(String loteria);

  /// No description provided for @muchosExitosJuego.
  ///
  /// In es, this message translates to:
  /// **'¡Muchos éxitos en tu juego! - Generado desde DataLoto App'**
  String get muchosExitosJuego;

  /// No description provided for @jugadaShare.
  ///
  /// In es, this message translates to:
  /// **'Jugada #{index}'**
  String jugadaShare(int index);

  /// No description provided for @noHayJugadasSeleccionadasImprimir.
  ///
  /// In es, this message translates to:
  /// **'No hay jugadas seleccionadas para imprimir'**
  String get noHayJugadasSeleccionadasImprimir;

  /// No description provided for @generaGuardaJugadas.
  ///
  /// In es, this message translates to:
  /// **'Genera y guarda tus jugadas desde la pantalla principal de {loteria}'**
  String generaGuardaJugadas(String loteria);

  /// No description provided for @confirmarEliminarVarios.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que deseas eliminar {count} jugada(s)?'**
  String confirmarEliminarVarios(int count);

  /// No description provided for @eliminadasExito.
  ///
  /// In es, this message translates to:
  /// **'Se eliminaron {count} jugada(s) correctamente.'**
  String eliminadasExito(int count);

  /// No description provided for @superbalotaConValor.
  ///
  /// In es, this message translates to:
  /// **'[Superbalota: {valor}]'**
  String superbalotaConValor(int valor);

  /// No description provided for @misJugadasConLoteria.
  ///
  /// In es, this message translates to:
  /// **'Mis Jugadas - {loteria}'**
  String misJugadasConLoteria(String loteria);

  /// No description provided for @whatsapp.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get whatsapp;

  /// No description provided for @nombreArchivoPDF.
  ///
  /// In es, this message translates to:
  /// **'Tiquete_{loteria}_DataLoto.pdf'**
  String nombreArchivoPDF(String loteria);

  /// No description provided for @usdDia.
  ///
  /// In es, this message translates to:
  /// **'USD / día'**
  String get usdDia;

  /// No description provided for @postEliminado.
  ///
  /// In es, this message translates to:
  /// **'Post eliminado correctamente'**
  String get postEliminado;

  /// No description provided for @errorEliminarPost.
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar el post: {error}'**
  String errorEliminarPost(String error);

  /// No description provided for @editarPost.
  ///
  /// In es, this message translates to:
  /// **'Editar Post'**
  String get editarPost;

  /// No description provided for @crearPost.
  ///
  /// In es, this message translates to:
  /// **'Crear Post'**
  String get crearPost;

  /// No description provided for @todosCamposObligatorios.
  ///
  /// In es, this message translates to:
  /// **'Todos los campos son obligatorios'**
  String get todosCamposObligatorios;

  /// No description provided for @errorGuardarPost.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar el post'**
  String get errorGuardarPost;

  /// No description provided for @contenido.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get contenido;

  /// No description provided for @publicar.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get publicar;

  /// No description provided for @escribeComentario.
  ///
  /// In es, this message translates to:
  /// **'Escribe un comentario'**
  String get escribeComentario;

  /// No description provided for @errorEnviarComentario.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar comentario: {error}'**
  String errorEnviarComentario(String error);

  /// No description provided for @comentarioEliminado.
  ///
  /// In es, this message translates to:
  /// **'Comentario eliminado'**
  String get comentarioEliminado;

  /// No description provided for @errorEliminarComentario.
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar: {error}'**
  String errorEliminarComentario(String error);

  /// No description provided for @comentarioReportado.
  ///
  /// In es, this message translates to:
  /// **'Comentario de @{usuario} reportado.'**
  String comentarioReportado(String usuario);

  /// No description provided for @respondiendoA.
  ///
  /// In es, this message translates to:
  /// **'Respondiendo a @{usuario}'**
  String respondiendoA(String usuario);

  /// No description provided for @escribeRespuesta.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu respuesta...'**
  String get escribeRespuesta;

  /// No description provided for @escribeComentarioHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un comentario...'**
  String get escribeComentarioHint;

  /// No description provided for @noHayComentarios.
  ///
  /// In es, this message translates to:
  /// **'No hay comentarios aún. ¡Sé el primero en comentar!'**
  String get noHayComentarios;

  /// No description provided for @opcionPago.
  ///
  /// In es, this message translates to:
  /// **'Opción de Pago'**
  String get opcionPago;

  /// No description provided for @completaDatosPago.
  ///
  /// In es, this message translates to:
  /// **'Completa tus datos de pago'**
  String get completaDatosPago;

  /// No description provided for @nombreTarjeta.
  ///
  /// In es, this message translates to:
  /// **'Nombre en la tarjeta'**
  String get nombreTarjeta;

  /// No description provided for @numeroTarjeta.
  ///
  /// In es, this message translates to:
  /// **'Número de tarjeta'**
  String get numeroTarjeta;

  /// No description provided for @ingresaNombre.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el nombre'**
  String get ingresaNombre;

  /// No description provided for @tarjetaInvalida.
  ///
  /// In es, this message translates to:
  /// **'Número de tarjeta inválido'**
  String get tarjetaInvalida;

  /// No description provided for @fechaInvalida.
  ///
  /// In es, this message translates to:
  /// **'Fecha inválida'**
  String get fechaInvalida;

  /// No description provided for @cvvInvalido.
  ///
  /// In es, this message translates to:
  /// **'CVV inválido'**
  String get cvvInvalido;

  /// No description provided for @pagar.
  ///
  /// In es, this message translates to:
  /// **'Pagar'**
  String get pagar;

  /// No description provided for @pagoExito.
  ///
  /// In es, this message translates to:
  /// **'✅ Pago realizado con éxito'**
  String get pagoExito;

  /// No description provided for @pagarEpayco.
  ///
  /// In es, this message translates to:
  /// **'Pagar con ePayco'**
  String get pagarEpayco;

  /// No description provided for @errorAnuncios.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar los anuncios.'**
  String get errorAnuncios;
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
