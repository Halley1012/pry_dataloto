class NotificationModel {
  final int id;
  final int? loteriaId;
  final DateTime? fechaSorteo;
  final String mensaje;
  final String tipo;
  final bool leido;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.loteriaId,
    this.fechaSorteo,
    required this.mensaje,
    required this.tipo,
    required this.leido,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      loteriaId: json['loteria_id'],
      fechaSorteo: json['fecha_sorteo'] != null ? DateTime.parse(json['fecha_sorteo']) : null,
      mensaje: json['mensaje'],
      tipo: json['tipo'],
      leido: json['leido'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loteria_id': loteriaId,
      'fecha_sorteo': fechaSorteo?.toIso8601String(),
      'mensaje': mensaje,
      'tipo': tipo,
      'leido': leido,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
