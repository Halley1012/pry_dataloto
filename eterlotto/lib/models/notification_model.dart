class NotificationModel {
  static DateTime _parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();

    final raw = value.toString().trim();
    if (raw.isEmpty) return DateTime.now();

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return DateTime.now();

    // PostgreSQL/FastAPI may serialize a UTC timestamp without Z/offset.
    // In that case DateTime.tryParse treats it as local time, so we rebuild
    // the same clock value explicitly as UTC. If an offset/Z is present,
    // Dart already preserves the correct instant.
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw);
    if (hasZone) return parsed;

    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  final int id;
  final int? loteriaId;
  final int? paisId;
  final String? loteriaNombre;
  final String? loteriaRoute;
  final DateTime? fechaSorteo;
  final String mensaje;
  final String tipo;
  final bool leido;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.loteriaId,
    this.paisId,
    this.loteriaNombre,
    this.loteriaRoute,
    this.fechaSorteo,
    required this.mensaje,
    required this.tipo,
    required this.leido,
    required this.createdAt,
  });

  NotificationModel copyWith({
    int? id,
    int? loteriaId,
    int? paisId,
    String? loteriaNombre,
    String? loteriaRoute,
    DateTime? fechaSorteo,
    String? mensaje,
    String? tipo,
    bool? leido,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      loteriaId: loteriaId ?? this.loteriaId,
      paisId: paisId ?? this.paisId,
      loteriaNombre: loteriaNombre ?? this.loteriaNombre,
      loteriaRoute: loteriaRoute ?? this.loteriaRoute,
      fechaSorteo: fechaSorteo ?? this.fechaSorteo,
      mensaje: mensaje ?? this.mensaje,
      tipo: tipo ?? this.tipo,
      leido: leido ?? this.leido,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      loteriaId: json['loteria_id'],
      paisId: json['pais_id'],
      loteriaNombre: json['loteria_nombre'],
      loteriaRoute: json['loteria_route'],
      fechaSorteo: json['fecha_sorteo'] != null ? DateTime.tryParse(json['fecha_sorteo'].toString()) : null,
      mensaje: json['mensaje'] ?? '',
      tipo: json['tipo'] ?? '',
      leido: json['leido'] ?? false,
      createdAt: _parseCreatedAt(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loteria_id': loteriaId,
      'pais_id': paisId,
      'loteria_nombre': loteriaNombre,
      'loteria_route': loteriaRoute,
      'fecha_sorteo': fechaSorteo?.toIso8601String(),
      'mensaje': mensaje,
      'tipo': tipo,
      'leido': leido,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
