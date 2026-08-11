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
}
