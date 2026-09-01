class NotificationModel {
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
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
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
