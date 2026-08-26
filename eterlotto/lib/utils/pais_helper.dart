import 'package:flutter/material.dart';

class PaisHelper {
  static String getBanderaEmoji(String nombre) {
    final n = nombre.toLowerCase().trim();
    if (n.contains("estados unidos") || n.contains("usa") || n.contains("eeuu") || n.contains("ee.uu") || n.contains("united states")) {
      return "🇺🇸";
    }
    if (n.contains("españa") || n.contains("espana") || n.contains("spain")) {
      return "🇪🇸";
    }
    if (n.contains("méxico") || n.contains("mexico")) {
      return "🇲🇽";
    }
    if (n.contains("brasil") || n.contains("brazil")) {
      return "🇧🇷";
    }
    if (n.contains("argentina")) {
      return "🇦🇷";
    }
    if (n.contains("colombia")) {
      return "🇨🇴";
    }
    if (n.contains("perú") || n.contains("peru")) {
      return "🇵🇪";
    }
    if (n.contains("chile")) {
      return "🇨🇱";
    }
    if (n.contains("venezuela")) {
      return "🇻🇪";
    }
    if (n.contains("ecuador")) {
      return "🇪🇨";
    }
    if (n.contains("bolivia")) {
      return "🇧🇴";
    }
    if (n.contains("uruguay")) {
      return "🇺🇾";
    }
    if (n.contains("paraguay")) {
      return "🇵🇾";
    }
    if (n.contains("panamá") || n.contains("panama")) {
      return "🇵🇦";
    }
    if (n.contains("costa rica")) {
      return "🇨🇷";
    }
    if (n.contains("guatemala")) {
      return "🇬🇹";
    }
    if (n.contains("dominicana")) {
      return "🇩🇴";
    }
    if (n.contains("puerto rico")) {
      return "🇵🇷";
    }
    if (n.contains("canadá") || n.contains("canada")) {
      return "🇨🇦";
    }
    if (n.contains("reino unido") || n.contains("inglaterra") || n.contains("uk")) {
      return "🇬🇧";
    }
    if (n.contains("francia") || n.contains("france")) {
      return "🇫🇷";
    }
    if (n.contains("italia") || n.contains("italy")) {
      return "🇮🇹";
    }
    if (n.contains("alemania") || n.contains("germany")) {
      return "🇩🇪";
    }
    if (n == "todos") {
      return "🌐";
    }
    return "🌐";
  }

  static String getNombreTraducido(String nombre, String langCode) {
    final n = nombre.toLowerCase().trim();
    if (langCode == 'en') {
      if (n.contains("estados unidos") || n.contains("usa") || n.contains("eeuu") || n.contains("united states")) {
        return "United States";
      }
      if (n.contains("españa") || n.contains("espana")) return "Spain";
      if (n.contains("méxico") || n.contains("mexico")) return "Mexico";
      if (n.contains("brasil")) return "Brazil";
      if (n.contains("alemania")) return "Germany";
      if (n.contains("francia")) return "France";
      if (n.contains("reino unido") || n.contains("inglaterra")) return "United Kingdom";
      if (n == "todos" || n == "internacional") return "International";
    } else if (langCode == 'pt') {
      if (n.contains("estados unidos") || n.contains("usa") || n.contains("eeuu") || n.contains("united states")) {
        return "Estados Unidos";
      }
      if (n.contains("españa") || n.contains("espana")) return "Espanha";
      if (n.contains("méxico") || n.contains("mexico")) return "México";
      if (n.contains("brasil")) return "Brasil";
      if (n.contains("alemania")) return "Alemanha";
      if (n.contains("francia")) return "França";
      if (n.contains("reino unido")) return "Reino Unido";
      if (n == "todos" || n == "internacional") return "Internacional";
    }
    if (nombre.isNotEmpty) {
      return nombre[0].toUpperCase() + nombre.substring(1).toLowerCase();
    }
    return nombre;
  }

  static Widget buildItemConBandera(String nombre, {TextStyle? style}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          getBanderaEmoji(nombre),
          style: const TextStyle(fontSize: 22),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            nombre,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String getMonedaByRoute(String? routeOrName, {String? rawText}) {
    final r = (routeOrName ?? "").toLowerCase().trim();
    final raw = (rawText ?? "").trim().toUpperCase();

    // 1. Detección por símbolo o código explícito en el texto
    if (raw.contains("MXN")) return "MXN";
    if (raw.contains("COP")) return "COP";
    if (raw.contains("UYU")) return "UYU";
    if (raw.contains("PEN")) return "PEN";
    if (raw.contains("BRL") || raw.startsWith("R\$")) return "BRL";
    if (raw.contains("EUR") || raw.contains("€")) return "EUR";
    if (raw.contains("USD") || raw.contains("US\$")) return "USD";
    if (raw.contains("ARS")) return "ARS";
    if (raw.contains("CLP")) return "CLP";
    if (raw.contains("PYG")) return "PYG";
    if (raw.contains("CRC")) return "CRC";
    if (raw.contains("DOP")) return "DOP";
    if (raw.contains("S/")) return "PEN";

    // 2. Detección por país o ruta de la lotería
    if (r.contains("5deoro") || r.contains("cincodeoro") || r.contains("uruguay")) return "UYU";
    if (r.contains("bloto") || r.contains("baloto") || r.contains("mloto") || r.contains("miloto") || r.contains("cloto") || r.contains("colorloto") || r.contains("colombia")) return "COP";
    if (r.contains("melate") || r.contains("chispazo") || r.contains("mexico") || r.contains("méxico")) return "MXN";
    if (r.contains("latinka") || r.contains("tinka") || r.contains("kabala") || r.contains("ganadiario") || r.contains("peru") || r.contains("perú")) return "PEN";
    if (r.contains("megasena") || r.contains("quina") || r.contains("duplasena") || r.contains("maismilionaria") || r.contains("brasil") || r.contains("brazil")) return "BRL";
    if (r.contains("primitiva") || r.contains("bonoloto") || r.contains("el_gordo") || r.contains("gordo") || r.contains("euromillones") || r.contains("eurodreams") || r.contains("espana") || r.contains("españa") || r.contains("spain") || r.contains("francia") || r.contains("italia") || r.contains("alemania")) return "EUR";
    if (r.contains("powerball") || r.contains("megamillions") || r.contains("lotto_america") || r.contains("double_play") || r.contains("millionaire_life") || r.contains("usa") || r.contains("eeuu") || r.contains("united_states") || r.contains("panama") || r.contains("panamá") || r.contains("ecuador")) return "USD";
    if (r.contains("argentina") || r.contains("quini6") || r.contains("loto_plus")) return "ARS";
    if (r.contains("chile") || r.contains("kino") || r.contains("loto_chile")) return "CLP";
    if (r.contains("costa_rica") || r.contains("costa rica")) return "CRC";
    if (r.contains("dominicana") || r.contains("leidsa")) return "DOP";
    if (r.contains("paraguay")) return "PYG";
    if (r.contains("bolivia")) return "BOB";
    if (r.contains("reino_unido") || r.contains("uk") || r.contains("national_lottery")) return "GBP";

    return "";
  }

  /// Separa el Jackpot en [valor, etiqueta] (ej: ["$55.200", "millones COP"], ["$48.000.000", "UYU"], ["R$ 87.000.000", "BRL"])
  static Map<String, String> getJackpotParts(String? raw, {String? loteriaRoute, String fallbackValue = ""}) {
    final String text = (raw == null || raw.trim().isEmpty) ? fallbackValue : raw.trim();
    if (text.isEmpty || text == "--") return {"value": fallbackValue.isNotEmpty ? fallbackValue : "--", "label": ""};

    final String defaultCurrency = getMonedaByRoute(loteriaRoute, rawText: text);

    // 1. Normalizar espacios duplicados
    String cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 2. Unificar moneda cuando viene separada con espacio (ej: "$ 48.000.000", "S/ 25,507,198", "R$ 87.000.000")
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^(R\$|\$|S\/|US\$)\s+(\d+)'),
      (match) => "${match.group(1)}${match.group(2)}",
    );

    // 3. Detectar si contiene sufijos de magnitud (ej: "$55.200 millones", "$10 Million", "$220,000,000 MXN", "59 Millones de Euros")
    final regexMagnitud = RegExp(
      r'^((?:R\$|\$|S\/|US\$)?\s*[\d\.,]+(?:\s*€)?)\s+(millones(?:\s+de\s+euros|\s+cop)?|million|millón|mxn|mdp|millões|\/.*|€\/.*)$',
      caseSensitive: false,
    );

    final matchMag = regexMagnitud.firstMatch(cleaned);
    if (matchMag != null) {
      String label = matchMag.group(2)?.trim() ?? "";
      if (label.toLowerCase() == "millones" && defaultCurrency.isNotEmpty) {
        label = "millones $defaultCurrency";
      } else if (label.toLowerCase() == "million" && defaultCurrency.isNotEmpty) {
        label = "Million $defaultCurrency";
      }
      return {
        "value": matchMag.group(1)?.trim() ?? cleaned,
        "label": label,
      };
    }

    // 4. Si es un monto con moneda (ej: "$48.000.000", "R$87.000.000,00", "14.500.000 €", "S/25,507,198")
    // Se adjunta la moneda oficial del país si la etiqueta quedó vacía
    return {
      "value": cleaned,
      "label": defaultCurrency,
    };
  }
}
