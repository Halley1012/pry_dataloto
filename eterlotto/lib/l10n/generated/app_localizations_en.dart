// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tituloApp => 'Eterlotto';

  @override
  String get iniciarSesion => 'Sign In';

  @override
  String get registrarse => 'Register';

  @override
  String get bienvenido => 'Welcome to Eterlotto!';

  @override
  String get descripcionBienvenida =>
      'We are excited to help you with smart predictions and make you enjoy the thrill of every draw to the max.';

  @override
  String get prediccionesInteligentes => 'Smart Predictions';

  @override
  String get ultimosResultados => 'Last 5 results';

  @override
  String get ultimosResultadosBaloto => 'Last 5 Baloto results';

  @override
  String get ultimosResultadosRevancha => 'Last 5 Baloto Revancha results';

  @override
  String get verMasResultados => 'See more results (50)';

  @override
  String get historicoResultadosTitulo => 'Results History';

  @override
  String ultimos50Resultados(String loteria) {
    return 'Last 50 draws of $loteria';
  }

  @override
  String get tusNumerosSuerte => 'Your lucky numbers';

  @override
  String get generar => 'Generate';

  @override
  String get guardar => 'Save';

  @override
  String get misJugadas => 'My Plays';

  @override
  String get estadisticas => 'Statistics';

  @override
  String get estadisticasAvanzadas => 'Advanced Statistics & Charts';

  @override
  String get seleccionaNumeros => 'Select your numbers';

  @override
  String get sorteosEvaluados => 'Draws Evaluated';

  @override
  String get numerosCalientes => 'Hot Numbers';

  @override
  String get numerosFrios => 'Cold Numbers';

  @override
  String get frecuenciaHistorica => 'Historical Frequency';

  @override
  String get ausenciaSorteos => 'Draws / Days Without Appearing';

  @override
  String get parImpar => 'Even vs Odd Distribution';

  @override
  String get bajosAltos => 'Low vs High';

  @override
  String get sumaCombinacion => 'Sum of Combination';

  @override
  String get parejasFrecuentes => 'Most Frequent Pairs';

  @override
  String get scoreProbabilidadIA => 'AI Probability Score';

  @override
  String get comparacionIA => 'Historical Behavior vs AI';

  @override
  String get idioma => 'Language';

  @override
  String get cambiarIdioma => 'Change Language';

  @override
  String get email => 'Email Address';

  @override
  String get contrasena => 'Password';

  @override
  String get olvidoContrasena => 'Forgot Password?';

  @override
  String get ingresar => 'Sign In';

  @override
  String get iniciaSesionParaContinuar => 'Sign in to continue';

  @override
  String get nombre => 'Name';

  @override
  String get crearCuenta => 'Create Account';

  @override
  String get notificaciones => 'Notifications';

  @override
  String get configuracion => 'Settings';

  @override
  String get cerrarSesion => 'Log Out';

  @override
  String get perfil => 'Profile';

  @override
  String get inicio => 'Home';

  @override
  String get resultados => 'Results';

  @override
  String get misAnuncios => 'My Ads';

  @override
  String get metodosPago => 'Payment Methods';

  @override
  String get invitarAmigos => 'Invite Friends';

  @override
  String get ayudaSoporte => 'Help & Support';

  @override
  String get eliminarCuenta => 'Delete Account';

  @override
  String get pais => 'Country';

  @override
  String get departamentoEstado => 'State / Region';

  @override
  String get editarPerfil => 'Edit Profile';

  @override
  String get guardarCambios => 'Save Changes';

  @override
  String get miPais => 'My Country';

  @override
  String get internacionales => 'International';

  @override
  String get todas => 'All';

  @override
  String get sinNotificaciones => 'No notifications yet';

  @override
  String get explorar => 'Explore';

  @override
  String get buscarLoteria => 'Search lottery...';

  @override
  String get populares => 'Popular';

  @override
  String get verTodas => 'View all';

  @override
  String get proximoSorteo => 'Next draw';

  @override
  String get todasLasLoterias => 'All Lotteries';

  @override
  String get comentarios => 'Comments';

  @override
  String get responder => 'Reply';

  @override
  String get respuesta => 'reply';

  @override
  String get respuestas => 'replies';

  @override
  String get sinPosts => 'No posts yet';

  @override
  String get anunciosDestacados => 'Featured Ads';

  @override
  String get derechosReservados => '© 2025 Eterlotto. All rights reserved.';

  @override
  String get version => 'Version';

  @override
  String get sinNotificacionesCategoria => 'No notifications for your country';

  @override
  String get verTodasNotificaciones => 'View all notifications';

  @override
  String get explorarLoterias => 'Explore Lotteries';

  @override
  String get buscarLoteriaOPais => 'Search lottery or country...';

  @override
  String get buscarPorLoteriaOPais => 'Search by lottery or country...';

  @override
  String get proximoSorteoConFecha => 'Next draw:';

  @override
  String get verTodasLoteriasMundo => 'View all lotteries of the world';

  @override
  String get analisisYResultados => 'Analysis & Results';

  @override
  String get aunNoTienesJugadas => 'You have no saved plays yet';

  @override
  String get empiezaAGuardarNumeros =>
      'Start saving your favorite numbers from the Explore section.';

  @override
  String get usuarioPremium => 'Premium User';

  @override
  String get ganaBeneficios => 'Earn benefits';

  @override
  String get avisoLegal => 'Legal Notice';

  @override
  String get acercaDe => 'About';

  @override
  String get cerrar => 'Close';

  @override
  String get contenidoAvisoLegal =>
      'This app is not official nor associated with lottery operators or gambling regulatory bodies in any country. It is not a lottery game, but a statistical analysis and artificial intelligence tool that generates predictions to help you choose your numbers with greater confidence. Results do not guarantee prizes and its use is solely for informational and entertainment purposes.';

  @override
  String get contenidoAcercaDe =>
      'Eterlotto uses artificial intelligence to analyze historical lottery patterns and provide informed predictions. Although our predictions are data-based, there is no absolute certainty that these numbers will win, as lottery is a game of chance. We do not guarantee prizes, we only help you choose with greater confidence. Use the app responsibly and only for entertainment purposes. The decision to use these predictions is under your own responsibility.';

  @override
  String get notificacionesIA => 'Notifications';

  @override
  String get marcarTodoComoLeido => 'Mark all as read';

  @override
  String get seleccionarTodo => 'Select all';

  @override
  String get desmarcarTodo => 'Unselect all';

  @override
  String get eliminar => 'Delete';

  @override
  String get imprimirPDF => 'Print PDF';

  @override
  String get historialJugadas => 'Play History';

  @override
  String get guardadasCantidad => 'saved';

  @override
  String get noTienesJugadasGuardadas => 'You have no saved plays yet';

  @override
  String get eliminarJugadas => 'Delete plays';

  @override
  String get confirmarCerrarSesion => 'Are you sure you want to log out?';

  @override
  String get idiomaSistema => 'System Language';

  @override
  String get seleccionarIdioma => 'Select Language';

  @override
  String get cancelar => 'Cancel';

  @override
  String get jackpotEstimado => 'Estimated Jackpot';

  @override
  String get millonesCOP => 'million COP';

  @override
  String get millonesUSD => 'million USD';

  @override
  String get resumenRapido => 'Quick summary';

  @override
  String get verEstadisticasCompletas => 'View full statistics ›';

  @override
  String get masCaliente => 'Hottest';

  @override
  String get masFrio => 'Coldest';

  @override
  String get prediccionIAHoy => 'AI Prediction for today';

  @override
  String basadaEnAnalisisDe(int count) {
    return 'Based on analysis of $count draws';
  }

  @override
  String get indiceAfinidadHistorica => 'Historical affinity index';

  @override
  String get tuJugadaSeleccionada => 'Your Selected Play';

  @override
  String balotasPrincipales(int count) {
    return '$count main balls';
  }

  @override
  String get balotaRoja => '1 red ball';

  @override
  String get tocaNumerosModificar => 'Tap numbers below to modify';

  @override
  String get numeroSuerteSugerido => 'Lucky number suggested by AI';

  @override
  String get jugada => 'Play';

  @override
  String get notaTendenciasEstadisticas =>
      'Note: these are only statistical tendencies, not absolute guarantees.';

  @override
  String get generarJugada => 'Generate Play';

  @override
  String get guardarJugada => 'Save Play';

  @override
  String get guardando => 'Saving...';

  @override
  String get jugadaGuardadaExito => 'Play saved successfully! 🎉';

  @override
  String get errorGuardarJugada => 'Error saving play';

  @override
  String get cargandoPrediccion => 'Loading prediction... Try again';

  @override
  String get debesSeleccionarBalotas =>
      'You must select 5 main balls and 1 red ball to save your play.';

  @override
  String get jugadaYaExiste => 'This play is already in your saved plays';

  @override
  String get balotasRojas => 'Red Balls';

  @override
  String get numerosOrdenadosProbabilidad =>
      'Numbers ordered from highest to lowest probability.';

  @override
  String get tocaNumeroSeleccionar => 'Tap a number to select it';

  @override
  String get ultimoSorteo => 'Last draw';

  @override
  String get sinNumeros => 'No numbers';

  @override
  String get noticiasAlertas => 'News / Alerts';

  @override
  String hoyEsSorteo(String loteria) {
    return 'Today is the $loteria draw';
  }

  @override
  String get noOlvidesRevisar =>
      'Don\'t forget to check your numbers and good luck.';

  @override
  String get paresImpares => 'Even - Odd';

  @override
  String get analizados => 'Analyzed';

  @override
  String get veces => 'times';

  @override
  String get versionApp => 'App version';

  @override
  String get tocaParaVerMas => 'Tap to see more';

  @override
  String get filtrosAnalisis => 'Analysis Filters';

  @override
  String get sorteos => 'Draws';

  @override
  String get tipo => 'Type';

  @override
  String get numerosCalientesFrios => 'Hot and Cold Numbers 🔥❄️';

  @override
  String get masFrecuentes => 'Most Frequent';

  @override
  String get menosFrecuentes => 'Least Frequent';

  @override
  String get ausenciaSorteosTitle => 'Draws / Days Without Appearing (Absence)';

  @override
  String get balotasMayorTiempo =>
      'Balls with the longest time without appearing:';

  @override
  String get apariciones => 'appearances';

  @override
  String get pareja => 'Pair';

  @override
  String get altaConsistenciaIA =>
      '✅ High consistency with historical even/odd patterns and sum dispersion.';

  @override
  String get moderadaConsistenciaIA =>
      '⚡ Moderate-high affinity with historical frequencies and balanced dispersion.';

  @override
  String get variabilidadConsistenciaIA =>
      '📊 High statistical variability behavior compared to previous trends.';

  @override
  String get comportamientoHistoricoVsIA => 'Historical Behavior vs AI ⚡';

  @override
  String get numerosMayorTendencia =>
      'Numbers with the highest historical trend:';

  @override
  String get prediccionActualIA => 'Current AI model prediction:';

  @override
  String get coberturaIA => 'AI Coverage';

  @override
  String get verTodasNotificacionesButton => 'View all notifications';

  @override
  String get sinNotificacionesAun => 'You have no notifications yet';

  @override
  String get miPaisFilter => 'My Country';

  @override
  String get internacionalesFilter => 'International';

  @override
  String get todasFilter => 'All';

  @override
  String get marcarLeido => 'Mark as read';

  @override
  String get errorConexion => 'Connection error';

  @override
  String get credencialesInvalidas => 'Invalid credentials';

  @override
  String get errorObtenerTokens => 'Error obtaining tokens';

  @override
  String get ingresaEmailContrasena => '⚠️ Enter email and password';

  @override
  String enviadoEnlace(String email) {
    return 'A link has been sent to $email';
  }

  @override
  String get recuperarContrasena => 'Recover Password';

  @override
  String get cancelarButton => 'Cancel';

  @override
  String get enviarButton => 'Send';

  @override
  String get noDisponible => 'Not available at the moment...';

  @override
  String estadisticasLoteria(String loteria) {
    return '$loteria Statistics';
  }

  @override
  String get rangoBalotas => 'Ball Range';

  @override
  String get powerballRoja => 'Red Powerball';

  @override
  String get starBall => 'Star Ball';

  @override
  String get megaBall => 'Mega Ball';

  @override
  String get cashBall => 'Cash Ball';

  @override
  String get errorCargarEstadisticas =>
      'Could not connect to the server to get statistics.';

  @override
  String promedioSumaHistorica(String valor) {
    return 'Average historical sum: $valor';
  }

  @override
  String get coberturaResultado => 'Result coverage';

  @override
  String numerosEnTopIA(int count) {
    return 'Numbers in the AI Top $count';
  }

  @override
  String hitsDeAciertos(int hits, int total) {
    return '$hits out of $total hits';
  }

  @override
  String get excelenteResultado => 'Excellent result! 🎯';

  @override
  String get buenDesempeno => 'Good performance 📊';

  @override
  String get insightsIA => 'AI Insights';

  @override
  String get resultadoReal => 'Real result';

  @override
  String get tendenciasIA => 'AI Trends';

  @override
  String get noHayTendencias => 'No detailed trends saved for this draw.';

  @override
  String sorteoDel(String fecha) {
    return 'Draw of $fecha';
  }

  @override
  String get revancha => 'Revancha';

  @override
  String ultimos5ResultadosNombre(Object nombre) {
    return 'Last 5 results $nombre';
  }

  @override
  String get ultimosSorteos => 'Last draws';

  @override
  String get reciente => 'Recent';

  @override
  String get prediccionesNoDisponibles =>
      'AI predictions for this past draw are not available in the history.';

  @override
  String insightIACayeron(int count, String loteria, String hits) {
    return 'Of the $count most likely numbers generated by the AI for $loteria, $hits matched.';
  }

  @override
  String insightIANoCoincidencias(int count, String loteria) {
    return 'Of the $count most likely numbers generated by the AI for $loteria, there were no matches in this draw.';
  }

  @override
  String insightIACayeronDual(
    int count,
    String loteria,
    String bText,
    String rText,
  ) {
    return 'Of the $count most likely numbers generated by the AI for $loteria, $bText and $rText matched.';
  }

  @override
  String get aciertoIA => 'AI Hit';

  @override
  String get balotasPrincipalesTitle => 'Main Balls';

  @override
  String get balotasRojasEspeciales => 'Red / Special Balls';

  @override
  String resultadosLoteria(String loteria) {
    return 'Results - $loteria';
  }

  @override
  String sorteoFechaLabel(String fecha) {
    return 'Draw: $fecha';
  }

  @override
  String get numerosGanadores => 'Winning numbers';

  @override
  String get comparacionJugadas => 'My Plays vs Result Comparison';

  @override
  String get aciertosLabel => 'Hits';

  @override
  String get balotaLabel => 'Ball';

  @override
  String get sinAciertoLabel => 'No hit';

  @override
  String get tusJugadasVsGanadores =>
      'Your saved plays vs Draw winning numbers';

  @override
  String get noRealizasteJugadas => 'You did not make any plays for this draw.';

  @override
  String cantidadAciertos(int count) {
    return '$count hit(s)';
  }

  @override
  String get fechaLabel => 'Date';

  @override
  String get aciertosSimple => 'Hits';

  @override
  String coberturaIndividualDetalle(int hits, int total, int top) {
    return '$hits out of $total winning numbers are in the top $top most likely';
  }

  @override
  String nEnBaloto(Object count, Object nums) {
    return '$count in Baloto ($nums)';
  }

  @override
  String get ceroEnBaloto => '0 in Baloto';

  @override
  String nEnRevancha(Object count, Object nums) {
    return '$count in Revancha ($nums)';
  }

  @override
  String get ceroEnRevancha => '0 in Revancha';

  @override
  String nNumeros(int count) {
    return '$count numbers';
  }

  @override
  String get errorEnviarCorreo => 'Error: Could not send email';

  @override
  String get usuarioRequerido => 'User required';

  @override
  String get correoInvalido => 'Invalid email';

  @override
  String get contrasenaMinima => 'Minimum 6 characters';

  @override
  String get seleccionaPais => 'Select a country';

  @override
  String get seleccionaDepartamento => 'Select a department';

  @override
  String get yaTienesCuenta => 'Already have an account? Sign in';

  @override
  String get actualizaTusDatos => 'Update your data';

  @override
  String get registroUsuario => 'User registration';

  @override
  String get modificaInformacion => 'Modify your information';

  @override
  String get confirmarEliminarCuenta =>
      'Are you sure you want to delete your account? This action is irreversible.';

  @override
  String get error => 'Error';

  @override
  String get sinResultadosAnalisis => 'No results analysis yet';

  @override
  String get buscaloAqui => 'Search Here';

  @override
  String get anunciateHoy =>
      'Advertise today and make yourself known to everyone!';

  @override
  String get crearNuevaPublicidad => 'Create new advertisement';

  @override
  String get buscarPorTitulo => 'Search by title';

  @override
  String get noHayAnunciosFiltros =>
      'No advertisements available \nfor the selected filters.';

  @override
  String get todos => 'All';

  @override
  String get todasCategorias => 'All categories';

  @override
  String get noHayPaisesDisponibles => 'No countries available';

  @override
  String get noHayDepartamentosDisponibles => 'No departments available';

  @override
  String get noHayCategoriasDisponibles => 'No categories available';

  @override
  String get estadoProvincia => 'State / Province';

  @override
  String get categoria => 'Category';

  @override
  String get presionaOtraVezSalir => 'Press again to exit';

  @override
  String get tusJugadasHoy => 'Your plays for today';

  @override
  String get errorCargarJugadas => 'Error loading plays';

  @override
  String get errorAgregarJugada => 'Error adding play';

  @override
  String get nro => 'No.';

  @override
  String get totalLabel => 'Total';

  @override
  String get misAnunciosTitle => 'My Ads';

  @override
  String get noHasPublicadoAnuncios =>
      'You haven\'t published any ads yet.\nCreate the first one now!';

  @override
  String get eliminarAnuncio => 'Delete ad';

  @override
  String get confirmarEliminarAnuncio =>
      'Are you sure you want to delete this ad?';

  @override
  String get editar => 'Edit';

  @override
  String get crearPublicidad => 'Create Advertisement';

  @override
  String get editarAnuncio => 'Edit Ad';

  @override
  String get crearNuevoAnuncio => 'Create new ad';

  @override
  String get promocionaNegocioStyle => 'Promote your business with style';

  @override
  String get titulo => 'Title';

  @override
  String get descripcion => 'Description';

  @override
  String get descripcionObligatoria => 'Description required';

  @override
  String get telefono => 'Phone';

  @override
  String get telefonoObligatorio => 'Phone required';

  @override
  String get direccion => 'Address';

  @override
  String get imagenUrl => 'Image URL';

  @override
  String get ciudad => 'City';

  @override
  String get redesSociales => 'Social networks';

  @override
  String get paginaWeb => 'Website';

  @override
  String get whatsappObligatorio => 'WhatsApp required';

  @override
  String get anuncioActualizado => 'Ad updated';

  @override
  String get anuncioCreado => 'Ad created';

  @override
  String get errorGuardar => 'Error saving';

  @override
  String campoRequerido(String campo) {
    return '$campo required';
  }

  @override
  String seleccionaCampo(String campo) {
    return 'Select $campo';
  }

  @override
  String misJugadasLoteria(String loteria) {
    return 'My $loteria Plays - Eterlotto';
  }

  @override
  String get noHayJugadasCompartir => 'No plays to share';

  @override
  String get buenaSuerteDataLoto => 'Good luck with Eterlotto!';

  @override
  String tiqueteDataloto(String loteria) {
    return 'ETERLOTTO - $loteria TICKET';
  }

  @override
  String reporteJugadasGuardadas(int count) {
    return 'Saved Plays Report ($count play(s))';
  }

  @override
  String get fechaGuardado => 'Saved Date';

  @override
  String balotasLoteria(String loteria) {
    return '$loteria Balls';
  }

  @override
  String get muchosExitosJuego =>
      'Much success in your game! - Generated from Eterlotto App';

  @override
  String jugadaShare(int index) {
    return 'Play #$index';
  }

  @override
  String get noHayJugadasSeleccionadasImprimir => 'No plays selected to print';

  @override
  String generaGuardaJugadas(String loteria) {
    return 'Generate and save your plays from the $loteria main screen';
  }

  @override
  String confirmarEliminarVarios(int count) {
    return 'Are you sure you want to delete $count play(s)?';
  }

  @override
  String eliminadasExito(int count) {
    return 'Successfully deleted $count play(s).';
  }

  @override
  String superbalotaConValor(int valor) {
    return '[Superball: $valor]';
  }

  @override
  String misJugadasConLoteria(String loteria) {
    return 'My Plays - $loteria';
  }

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String nombreArchivoPDF(String loteria) {
    return 'Ticket_${loteria}_Eterlotto.pdf';
  }

  @override
  String get usdDia => 'USD / day';

  @override
  String get postEliminado => 'Post deleted successfully';

  @override
  String errorEliminarPost(String error) {
    return 'Error deleting post: $error';
  }

  @override
  String get editarPost => 'Edit Post';

  @override
  String get crearPost => 'Create Post';

  @override
  String get todosCamposObligatorios => 'All fields are required';

  @override
  String get errorGuardarPost => 'Error saving post';

  @override
  String get contenido => 'Content';

  @override
  String get publicar => 'Publish';

  @override
  String get escribeComentario => 'Write a comment';

  @override
  String errorEnviarComentario(String error) {
    return 'Error sending comment: $error';
  }

  @override
  String get comentarioEliminado => 'Comment deleted';

  @override
  String errorEliminarComentario(String error) {
    return 'Error deleting: $error';
  }

  @override
  String comentarioReportado(String usuario) {
    return 'Comment from @$usuario reported.';
  }

  @override
  String respondiendoA(String usuario) {
    return 'Replying to @$usuario';
  }

  @override
  String get escribeRespuesta => 'Write your reply...';

  @override
  String get escribeComentarioHint => 'Write a comment...';

  @override
  String get noHayComentarios => 'No comments yet. Be the first to comment!';

  @override
  String get opcionPago => 'Payment Option';

  @override
  String get completaDatosPago => 'Complete your payment details';

  @override
  String get nombreTarjeta => 'Name on card';

  @override
  String get numeroTarjeta => 'Card Number';

  @override
  String get ingresaNombre => 'Enter name';

  @override
  String get tarjetaInvalida => 'Invalid card number';

  @override
  String get fechaInvalida => 'Invalid date';

  @override
  String get cvvInvalido => 'Invalid CVV';

  @override
  String get pagar => 'Pay';

  @override
  String get pagoExito => '✅ Payment successful';

  @override
  String get pagarEpayco => 'Pay with ePayco';

  @override
  String get errorAnuncios => 'Error loading ads.';

  @override
  String get numerosLabel => 'Numbers';
}
