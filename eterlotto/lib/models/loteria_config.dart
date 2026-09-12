import 'package:eterlotto/models/lottery_number_layout.dart';

class LoteriaConfig {
  final int? loteriaId;
  final int? paisId;
  final String? paisNombre;
  final String nombre;
  final String route;
  final int maxSeleccion;
  final int maxBalotasBlancas;
  final int maxBalotasRojas;
  final String superbalotaNombre;
  final bool hasRevancha;
  final int totalBalotasSorteo;
  final bool tieneComplementario;
  final bool tieneReintegro;

  const LoteriaConfig({
    this.loteriaId,
    this.paisId,
    this.paisNombre,
    required this.nombre,
    required this.route,
    this.maxSeleccion = 5,
    this.maxBalotasBlancas = 45,
    this.maxBalotasRojas = 0,
    this.superbalotaNombre = "Superbalota",
    this.hasRevancha = false,
    this.totalBalotasSorteo = 5,
    this.tieneComplementario = false,
    this.tieneReintegro = false,
  });

  bool get tieneBalotaRoja => cantidadEspeciales > 0;

  /// Regla estructural única: principales, especiales y complementaria se
  /// separan exclusivamente por posición.
  LotteryNumberLayout get numberLayout => LotteryNumberLayout.fromConfig(
        maxSeleccion: maxSeleccion,
        totalBalotasSorteo: totalBalotasSorteo,
        tieneComplementario: tieneComplementario,
      );

  int get cantidadEspeciales => numberLayout.specialCount;
  int get cantidadComplementarias => numberLayout.complementaryCount;

  Map<String, dynamic> toJson() {
    final specialNumbersCount =
        (totalBalotasSorteo - maxSeleccion - (tieneComplementario ? 1 : 0))
                .clamp(0, totalBalotasSorteo)
            as int;
    return {
      if (loteriaId != null) 'id': loteriaId,
      if (loteriaId != null) 'loteria_id': loteriaId,
      if (paisId != null) 'pais_id': paisId,
      if (paisNombre != null && paisNombre!.trim().isNotEmpty) 'pais_nombre': paisNombre,
      'nombre': nombre,
      'route': route,
      'max_seleccion': maxSeleccion,
      'max_balotas_blancas': maxBalotasBlancas,
      'max_balotas_rojas': maxBalotasRojas,
      'special_numbers_count': specialNumbersCount,
      'superbalota_nombre': superbalotaNombre,
      'has_revancha': hasRevancha,
      'total_balotas_sorteo': totalBalotasSorteo,
      'tiene_complementario': tieneComplementario,
      'tiene_reintegro': tieneReintegro,
    };
  }

  LoteriaConfig copyWith({
    int? loteriaId,
    int? paisId,
    String? paisNombre,
    String? nombre,
    String? route,
    int? maxSeleccion,
    int? maxBalotasBlancas,
    int? maxBalotasRojas,
    String? superbalotaNombre,
    bool? hasRevancha,
    int? totalBalotasSorteo,
    bool? tieneComplementario,
    bool? tieneReintegro,
  }) {
    return LoteriaConfig(
      loteriaId: loteriaId ?? this.loteriaId,
      paisId: paisId ?? this.paisId,
      paisNombre: paisNombre ?? this.paisNombre,
      nombre: nombre ?? this.nombre,
      route: route ?? this.route,
      maxSeleccion: maxSeleccion ?? this.maxSeleccion,
      maxBalotasBlancas: maxBalotasBlancas ?? this.maxBalotasBlancas,
      maxBalotasRojas: maxBalotasRojas ?? this.maxBalotasRojas,
      superbalotaNombre: superbalotaNombre ?? this.superbalotaNombre,
      hasRevancha: hasRevancha ?? this.hasRevancha,
      totalBalotasSorteo: totalBalotasSorteo ?? this.totalBalotasSorteo,
      tieneComplementario: tieneComplementario ?? this.tieneComplementario,
      tieneReintegro: tieneReintegro ?? this.tieneReintegro,
    );
  }

  /// Construye la configuración dinámicamente desde el mapa devuelto por el API / Base de Datos
  static LoteriaConfig fromJson(
    Map<String, dynamic> json, {
    String? fallbackNombre,
  }) {
    final rawNombre = json["nombre"]?.toString() ?? fallbackNombre ?? "Lotería";
    final rawRoute =
        (json["route"] != null && json["route"].toString().isNotEmpty)
        ? json["route"].toString().trim().toLowerCase()
        : _inferRouteFromName(rawNombre);

    final maxSel = json["max_seleccion"] != null
        ? int.tryParse(json["max_seleccion"].toString())
        : (json["maxSeleccion"] != null
              ? int.tryParse(json["maxSeleccion"].toString())
              : null);

    final maxBlancas = json["max_balotas_blancas"] != null
        ? int.tryParse(json["max_balotas_blancas"].toString())
        : (json["max_balotas"] != null
              ? int.tryParse(json["max_balotas"].toString())
              : (json["maxBalotasBlancas"] != null
                    ? int.tryParse(json["maxBalotasBlancas"].toString())
                    : null));

    final maxRojas = json["max_balotas_rojas"] != null
        ? int.tryParse(json["max_balotas_rojas"].toString())
        : (json["maxBalotasRojas"] != null
              ? int.tryParse(json["maxBalotasRojas"].toString())
              : null);

    final superNombre =
        json["superbalota_nombre"]?.toString() ??
        json["superbalotaNombre"]?.toString();

    final revancha =
        json["has_revancha"] == true || json["hasRevancha"] == true;

    final tieneComp =
        json["tiene_complementario"] == true ||
        json["tieneComplementario"] == true;

    final tieneReintegro =
        json["tiene_reintegro"] == true || json["tieneReintegro"] == true;

    final specialCount = json["special_numbers_count"] != null
        ? int.tryParse(json["special_numbers_count"].toString())
        : (json["specialNumbersCount"] != null
              ? int.tryParse(json["specialNumbersCount"].toString())
              : null);
    final int totalSorteoFallback =
        (maxSel ?? 5) +
        (specialCount ?? ((maxRojas ?? 0) > 0 ? 1 : 0)) +
        (tieneComp ? 1 : 0);
    final totalSorteo = json["total_balotas_sorteo"] != null
        ? int.tryParse(json["total_balotas_sorteo"].toString())
        : (json["totalBalotasSorteo"] != null
              ? int.tryParse(json["totalBalotasSorteo"].toString())
              : null);

    final loteriaId = int.tryParse(
      (json["loteria_id"] ?? json["id"])?.toString() ?? "",
    );
    final paisId = int.tryParse(json["pais_id"]?.toString() ?? "");

    final rawPais = json["pais"];
    final paisNombreRaw =
        json["pais_nombre"] ??
        json["paisNombre"] ??
        json["nombre_pais"] ??
        json["country_name"] ??
        json["countryName"] ??
        (rawPais is Map ? (rawPais["nombre"] ?? rawPais["name"]) : rawPais);
    final paisNombre = paisNombreRaw?.toString().trim();

    return LoteriaConfig(
      loteriaId: loteriaId,
      paisId: paisId,
      paisNombre: (paisNombre != null && paisNombre.isNotEmpty) ? paisNombre : null,
      nombre: rawNombre,
      route: rawRoute,
      maxSeleccion: maxSel ?? 5,
      maxBalotasBlancas: maxBlancas ?? 45,
      maxBalotasRojas: maxRojas ?? 0,
      superbalotaNombre: superNombre ?? "Superbalota",
      hasRevancha: revancha,
      totalBalotasSorteo: totalSorteo ?? totalSorteoFallback,
      tieneComplementario: tieneComp,
      tieneReintegro: tieneReintegro,
    );
  }

  /// Constructor fallback cuando solo se conoce el nombre o la ruta
  static LoteriaConfig fromNombre(
    String? nombreInput, {
    String? routeOverride,
  }) {
    final t = (nombreInput ?? "Lotería").trim();
    final cleanRoute = (routeOverride != null && routeOverride.isNotEmpty)
        ? routeOverride.trim().toLowerCase()
        : _inferRouteFromName(t);

    final formattedName = t.isNotEmpty
        ? t[0].toUpperCase() + t.substring(1)
        : "Lotería";

    final tieneComp =
        cleanRoute.contains("bonoloto") || cleanRoute.contains("primitiva");
    final tieneReintegro =
        cleanRoute.contains("bonoloto") ||
        cleanRoute.contains("primitiva") ||
        cleanRoute.contains("el_gordo");
    final int maxSel =
        (cleanRoute.contains("kabala") ||
            cleanRoute.contains("latinka") ||
            cleanRoute.contains("tinka") ||
            cleanRoute.contains("duplasena") ||
            cleanRoute.contains("bonoloto") ||
            cleanRoute.contains("primitiva") ||
            cleanRoute.contains("cloto") ||
            cleanRoute.contains("eurodreams") ||
            cleanRoute.contains("megasena") ||
            cleanRoute.contains("maismilionaria") ||
            cleanRoute.contains("melate"))
        ? 6
        : 5;
    final int maxRojas =
        (cleanRoute.contains("lotto_cr") ||
            cleanRoute.contains("ganadiario") ||
            cleanRoute.contains("kabala") ||
            cleanRoute.contains("duplasena") ||
            cleanRoute.contains("quina") ||
            cleanRoute.contains("chispazo") ||
            cleanRoute.contains("mloto") ||
            cleanRoute.contains("cloto") ||
            cleanRoute.contains("megasena"))
        ? 0
        : (cleanRoute.contains("maismilionaria")
              ? 6
              : (cleanRoute.contains("5deoro") ||
                        cleanRoute.contains("cincodeoro")
                    ? 48
                    : (cleanRoute.contains("latinka") ||
                              cleanRoute.contains("tinka")
                          ? 50
                          : (cleanRoute.contains("melateretro") ||
                                    cleanRoute.contains("retro")
                                ? 39
                                : (cleanRoute.contains("melate") ? 56 : 10)))));
    final int maxBlancas = cleanRoute.contains("quina")
        ? 80
        : (cleanRoute.contains("megasena")
              ? 60
              : (cleanRoute.contains("duplasena") ||
                        cleanRoute.contains("latinka") ||
                        cleanRoute.contains("tinka")
                    ? 50
                    : (cleanRoute.contains("5deoro") ||
                              cleanRoute.contains("cincodeoro")
                          ? 48
                          : (cleanRoute.contains("kabala") ||
                                    cleanRoute.contains("lotto_cr")
                                ? 40
                                : (cleanRoute.contains("ganadiario")
                                      ? 35
                                      : (cleanRoute.contains("chispazo")
                                            ? 28
                                            : (cleanRoute.contains(
                                                        "melateretro",
                                                      ) ||
                                                      cleanRoute.contains(
                                                        "retro",
                                                      )
                                                  ? 39
                                                  : (cleanRoute.contains(
                                                          "melate",
                                                        )
                                                        ? 56
                                                        : (cleanRoute.contains(
                                                                "maismilionaria",
                                                              )
                                                              ? 50
                                                              : 45)))))))));
    final String sbNombre =
        cleanRoute.contains("5deoro") || cleanRoute.contains("cincodeoro")
        ? "Bolilla Extra"
        : (cleanRoute.contains("latinka") || cleanRoute.contains("tinka")
              ? "Boliyapa"
              : (cleanRoute.contains("maismilionaria")
                    ? "Tréboles"
                    : (cleanRoute.contains("melate")
                          ? "Adicional"
                          : "Superbalota")));
    final bool hasRev =
        cleanRoute.contains("lotto_cr") ||
        cleanRoute.contains("kabala") ||
        cleanRoute.contains("5deoro") ||
        cleanRoute.contains("cincodeoro") ||
        cleanRoute.contains("duplasena") ||
        (!cleanRoute.contains("retro") && cleanRoute.contains("melate")) ||
        cleanRoute.contains("baloto") ||
        cleanRoute.contains("bloto");
    final int totalSorteo =
        maxSel +
        (maxRojas > 0 ? (cleanRoute.contains("maismilionaria") ? 2 : 1) : 0) +
        (tieneComp ? 1 : 0);

    return LoteriaConfig(
      nombre: formattedName,
      route: cleanRoute,
      maxSeleccion: maxSel,
      maxBalotasBlancas: maxBlancas,
      maxBalotasRojas: maxRojas,
      superbalotaNombre: sbNombre,
      hasRevancha: hasRev,
      totalBalotasSorteo: totalSorteo,
      tieneComplementario: tieneComp,
      tieneReintegro: tieneReintegro,
    );
  }

  static String _inferRouteFromName(String t) {
    return t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }
}
