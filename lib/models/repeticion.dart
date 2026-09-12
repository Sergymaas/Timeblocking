
// ─── Frecuencia de repetición ────────────────────────────────────────────────
 
enum Frecuencia { diaria, semanal, bisemanal, mensual }
 
// ─── Repetición (embebida dentro de Bloque) ──────────────────────────────────
 
class Repeticion {
  final Frecuencia frecuencia;
 
  /// Días de la semana: 0 = lunes, 6 = domingo.
  /// Ejemplo: [0, 2, 4] = lunes, miércoles y viernes.
  final List<int> dias;
  final DateTime? fechaLimite;
 
  const Repeticion({
    required this.frecuencia,
    required this.dias, String? notas,
    this.fechaLimite,
  });
 
  Map<String, dynamic> toMap() {
    return {
      'frecuencia': frecuencia.index,
      'dias': dias.join(','),
      'fecha_limite': fechaLimite?.toIso8601String(),
    };
  }
 
  factory Repeticion.fromMap(Map<String, dynamic> map) {
    return Repeticion(
      frecuencia: Frecuencia.values[map['frecuencia'] as int],
      dias: (map['dias'] as String).split(',').map(int.parse).toList(),
      fechaLimite: map['fecha_limite'] != null 
        ? DateTime.parse(map['fecha_limite'] as String) 
        : null,
    );
  }
}