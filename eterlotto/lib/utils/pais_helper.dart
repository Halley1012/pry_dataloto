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
    if (n.contains("irlanda") || n.contains("ireland")) {
      return "🇮🇪";
    }
    if (n.contains("luxemburgo") || n.contains("luxembourg")) {
      return "🇱🇺";
    }
    if (n.contains("bélgica") || n.contains("belgica") || n.contains("belgium")) {
      return "🇧🇪";
    }
    if (n.contains("austria") || n.contains("áustria")) {
      return "🇦🇹";
    }
    if (n.contains("portugal")) {
      return "🇵🇹";
    }
    if (n.contains("suiza") || n.contains("suíça") || n.contains("switzerland")) {
      return "🇨🇭";
    }
    if (n == "todos") {
      return "🌐";
    }
    return "🌐";
  }

  static String getIsoCode(String nombre) {
    final n = nombre.toLowerCase().trim();
    if (n.contains("estados unidos") || n.contains("usa") || n.contains("eeuu") || n.contains("ee.uu") || n.contains("united states")) {
      return "US";
    }
    if (n.contains("españa") || n.contains("espana") || n.contains("spain")) return "ES";
    if (n.contains("méxico") || n.contains("mexico")) return "MX";
    if (n.contains("brasil") || n.contains("brazil")) return "BR";
    if (n.contains("argentina")) return "AR";
    if (n.contains("colombia")) return "CO";
    if (n.contains("perú") || n.contains("peru")) return "PE";
    if (n.contains("chile")) return "CL";
    if (n.contains("venezuela")) return "VE";
    if (n.contains("ecuador")) return "EC";
    if (n.contains("bolivia")) return "BO";
    if (n.contains("uruguay")) return "UY";
    if (n.contains("paraguay")) return "PY";
    if (n.contains("panamá") || n.contains("panama")) return "PA";
    if (n.contains("costa rica")) return "CR";
    if (n.contains("guatemala")) return "GT";
    if (n.contains("dominicana")) return "DO";
    if (n.contains("puerto rico")) return "PR";
    if (n.contains("canadá") || n.contains("canada")) return "CA";
    if (n.contains("reino unido") || n.contains("inglaterra") || n.contains("uk")) return "GB";
    if (n.contains("francia") || n.contains("france")) return "FR";
    if (n.contains("italia") || n.contains("italy")) return "IT";
    if (n.contains("alemania") || n.contains("germany")) return "DE";
    if (n.contains("irlanda") || n.contains("ireland")) return "IE";
    if (n.contains("luxemburgo") || n.contains("luxembourg")) return "LU";
    if (n.contains("bélgica") || n.contains("belgica") || n.contains("belgium")) return "BE";
    if (n.contains("austria") || n.contains("áustria")) return "AT";
    if (n.contains("portugal")) return "PT";
    if (n.contains("suiza") || n.contains("suíça") || n.contains("switzerland")) return "CH";
    if (n.contains("honduras")) return "HN";
    if (n.contains("el salvador")) return "SV";
    if (n.contains("nicaragua")) return "NI";
    if (n.contains("europa") || n.contains("europe")) return "EU";
    return "";
  }

  /// El país debe venir de `pais_id`/`pais_nombre` del catálogo.
  /// Se conserva el método sólo para compatibilidad mientras terminan de
  /// migrarse callers antiguos; nunca infiere país desde la route.
  static String getPaisNameByRoute(String? routeOrName) => "";

  static String getDialCode(String nombre) {
    final n = nombre.toLowerCase().trim();
    if (n.contains("estados unidos") || n.contains("usa") || n.contains("eeuu") || n.contains("ee.uu") || n.contains("united states")) {
      return "+1";
    }
    if (n.contains("españa") || n.contains("espana") || n.contains("spain")) return "+34";
    if (n.contains("méxico") || n.contains("mexico")) return "+52";
    if (n.contains("brasil") || n.contains("brazil")) return "+55";
    if (n.contains("argentina")) return "+54";
    if (n.contains("colombia")) return "+57";
    if (n.contains("perú") || n.contains("peru")) return "+51";
    if (n.contains("chile")) return "+56";
    if (n.contains("venezuela")) return "+58";
    if (n.contains("ecuador")) return "+593";
    if (n.contains("bolivia")) return "+591";
    if (n.contains("uruguay")) return "+598";
    if (n.contains("paraguay")) return "+595";
    if (n.contains("panamá") || n.contains("panama")) return "+507";
    if (n.contains("costa rica")) return "+506";
    if (n.contains("guatemala")) return "+502";
    if (n.contains("dominicana")) return "+1";
    if (n.contains("puerto rico")) return "+1";
    if (n.contains("canadá") || n.contains("canada")) return "+1";
    if (n.contains("reino unido") || n.contains("inglaterra") || n.contains("uk")) return "+44";
    if (n.contains("francia") || n.contains("france")) return "+33";
    if (n.contains("italia") || n.contains("italy")) return "+39";
    if (n.contains("alemania") || n.contains("germany")) return "+49";
    if (n.contains("irlanda") || n.contains("ireland")) return "+353";
    if (n.contains("luxemburgo") || n.contains("luxembourg")) return "+352";
    if (n.contains("bélgica") || n.contains("belgica") || n.contains("belgium")) return "+32";
    if (n.contains("austria") || n.contains("áustria")) return "+43";
    if (n.contains("portugal")) return "+351";
    if (n.contains("suiza") || n.contains("suíça") || n.contains("switzerland")) return "+41";
    if (n.contains("honduras")) return "+504";
    if (n.contains("el salvador")) return "+503";
    if (n.contains("nicaragua")) return "+505";
    return "";
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
      if (n.contains("irlanda")) return "Ireland";
      if (n.contains("luxemburgo")) return "Luxembourg";
      if (n.contains("bélgica") || n.contains("belgica")) return "Belgium";
      if (n.contains("austria") || n.contains("áustria")) return "Austria";
      if (n.contains("portugal")) return "Portugal";
      if (n.contains("suiza") || n.contains("suíça")) return "Switzerland";
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
      if (n.contains("irlanda")) return "Irlanda";
      if (n.contains("luxemburgo")) return "Luxemburgo";
      if (n.contains("bélgica") || n.contains("belgica")) return "Bélgica";
      if (n.contains("austria") || n.contains("áustria")) return "Áustria";
      if (n.contains("portugal")) return "Portugal";
      if (n.contains("suiza") || n.contains("suíça")) return "Suíça";
      if (n.contains("reino unido")) return "Reino Unido";
      if (n == "todos" || n == "internacional") return "Internacional";
    } else if (langCode == 'fr') {
      if (n.contains("estados unidos") || n.contains("usa") || n.contains("eeuu") || n.contains("united states")) return "États-Unis";
      if (n.contains("españa") || n.contains("espana")) return "Espagne";
      if (n.contains("méxico") || n.contains("mexico")) return "Mexique";
      if (n.contains("brasil")) return "Brésil";
      if (n.contains("alemania")) return "Allemagne";
      if (n.contains("francia")) return "France";
      if (n.contains("irlanda")) return "Irlande";
      if (n.contains("luxemburgo")) return "Luxembourg";
      if (n.contains("bélgica") || n.contains("belgica")) return "Belgique";
      if (n.contains("austria") || n.contains("áustria")) return "Autriche";
      if (n.contains("portugal")) return "Portugal";
      if (n.contains("suiza") || n.contains("suíça")) return "Suisse";
      if (n.contains("reino unido") || n.contains("inglaterra")) return "Royaume-Uni";
      if (n == "todos" || n == "internacional") return "International";
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

  /// Detecta moneda únicamente cuando el propio dato la declara.
  /// La route de una lotería no identifica de forma fiable un país/moneda.
  static String getMonedaByRoute(String? routeOrName, {String? rawText}) {
    final raw = (rawText ?? "").trim().toUpperCase();

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
    if (raw.contains("CRC") || raw.contains("₡")) return "CRC";
    if (raw.contains("DOP")) return "DOP";
    if (raw.contains("GBP") || raw.contains("£")) return "GBP";
    if (raw.contains("BOB")) return "BOB";
    if (raw.contains("S/")) return "PEN";

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
