import 'repeticion.dart';

// ─── Bloque ──────────────────────────────────────────────────────────────────
 
class Bloque {
  final int? id;
  final String titulo;
  final DateTime horaInicio;
  final DateTime horaFin;
  final Duration duracion;
  final int categoriaId;
  final int? subcategoriaId;
  final Repeticion? repeticion;
  final String? notas;
  final bool notificacionInicio;
  final int? minutosAntes;
  final bool esOcurrencia;
  final int? bloqueOriginalId;
  final int? plantillaId;
  final bool completado;
 
  const Bloque({
    this.id,
    required this.titulo,
    required this.horaInicio,
    required this.horaFin,
    required this.duracion,
    required this.categoriaId,
    this.subcategoriaId,
    this.repeticion,
    this.notas,
    this.notificacionInicio = false,
    this.minutosAntes,
    this.esOcurrencia = false,
    this.bloqueOriginalId,
    this.plantillaId,
    this.completado = false,
  });


  // ─── Constructores por modo de entrada ─────────────────────────────────────
 
  /// Modo 1: inicio + fin → duración calculada.
  factory Bloque.desdeInicioYFin({
    int? id,
    required String titulo,
    required DateTime horaInicio,
    required DateTime horaFin,
    required int categoriaId,
    int? subcategoriaId,
    Repeticion? repeticion,
    String? notas,
    bool notificacionInicio = false,
    int? minutosAntes,
    bool esOcurrencia = false,
    int? bloqueOriginalId,
    int? plantillaId,
    bool completado = false,
  }) {
    assert(horaFin.isAfter(horaInicio), 'hora_fin debe ser posterior a hora_inicio');
    return Bloque(
      id: id,
      titulo: titulo,
      horaInicio: horaInicio,
      horaFin: horaFin,
      duracion: horaFin.difference(horaInicio),
      categoriaId: categoriaId,
      subcategoriaId: subcategoriaId,
      repeticion: repeticion,
      notas: notas,
      notificacionInicio: notificacionInicio,
      minutosAntes: minutosAntes,
      esOcurrencia: esOcurrencia,
      bloqueOriginalId: bloqueOriginalId,
      plantillaId: plantillaId,
      completado: completado,
    );
  }
 
  /// Modo 2: inicio + duración → fin calculado.
  factory Bloque.desdeInicioYDuracion({
    int? id,
    required String titulo,
    required DateTime horaInicio,
    required Duration duracion,
    required int categoriaId,
    int? subcategoriaId,
    Repeticion? repeticion,
    String? notas,
    bool notificacionInicio = false,
    int? minutosAntes,
    bool esOcurrencia = false,
    int? bloqueOriginalId,
    int? plantillaId,
    bool completado = false,
  }) {
    return Bloque(
      id: id,
      titulo: titulo,
      horaInicio: horaInicio,
      horaFin: horaInicio.add(duracion),
      duracion: duracion,
      categoriaId: categoriaId,
      subcategoriaId: subcategoriaId,
      repeticion: repeticion,
      notas: notas,
      notificacionInicio: notificacionInicio,
      minutosAntes: minutosAntes,
      plantillaId: plantillaId,
      completado: completado,
    );
  }
 
  /// Modo 3: fin + duración → inicio calculado.
  factory Bloque.desdeFinYDuracion({
    int? id,
    required String titulo,
    required DateTime horaFin,
    required Duration duracion,
    required int categoriaId,
    int? subcategoriaId,
    Repeticion? repeticion,
    String? notas,
    bool notificacionInicio = false,
    int? minutosAntes,
    bool esOcurrencia = false,
    int? bloqueOriginalId,
    int? plantillaId,
    bool completado = false,
  }) {
    return Bloque(
      id: id,
      titulo: titulo,
      horaInicio: horaFin.subtract(duracion),
      horaFin: horaFin,
      duracion: duracion,
      categoriaId: categoriaId,
      subcategoriaId: subcategoriaId,
      repeticion: repeticion,
      notas: notas,
      notificacionInicio: notificacionInicio,
      minutosAntes: minutosAntes,
      plantillaId: plantillaId,
      completado: completado,
    );
  }
 
  // ─── Mover el bloque conservando la duración ────────────────────────────────
 
  /// Cambia hora_inicio y recalcula hora_fin. La duración no cambia.
  Bloque moverA(DateTime nuevaHoraInicio) {
    return Bloque(
      id: id,
      titulo: titulo,
      horaInicio: nuevaHoraInicio,
      horaFin: nuevaHoraInicio.add(duracion),
      duracion: duracion,
      categoriaId: categoriaId,
      subcategoriaId: subcategoriaId,
      repeticion: repeticion,
      notas: notas,
      notificacionInicio: notificacionInicio,
      minutosAntes: minutosAntes,
      esOcurrencia: esOcurrencia,
      bloqueOriginalId: bloqueOriginalId,
      plantillaId: plantillaId,
      completado: completado,
    );
  }
 
  // ─── Serialización ──────────────────────────────────────────────────────────
 
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'hora_inicio': horaInicio.toIso8601String(),
      'hora_fin': horaFin.toIso8601String(),
      'duracion_minutos': duracion.inMinutes,
      'categoria_id': categoriaId,
      'subcategoria_id': subcategoriaId,
      'repeticion_frecuencia': repeticion?.frecuencia.index,
      'repeticion_dias': repeticion?.dias.join(','),
      'notas': notas,
      'notificacion_inicio': notificacionInicio ? 1 : 0,
      'minutos_antes': minutosAntes,
      'bloque_original_id': bloqueOriginalId,
      'plantilla_id': plantillaId,
      'completado': completado ? 1 : 0,
      'repeticion_fecha_limite': repeticion?.fechaLimite?.toIso8601String(),
    };
  }
 
factory Bloque.fromMap(Map<String, dynamic> map) {
  Repeticion? repeticion;
  if (map['repeticion_frecuencia'] != null) {
    repeticion = Repeticion(
      frecuencia: Frecuencia.values[map['repeticion_frecuencia'] as int],
      dias: (map['repeticion_dias'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toList(),
      fechaLimite: map['repeticion_fecha_limite'] != null
        ? DateTime.parse(map['repeticion_fecha_limite'] as String)
        : null,
    );
  }
  return Bloque(
    id: map['id'] as int?,
    titulo: map['titulo'] as String,
    horaInicio: DateTime.parse(map['hora_inicio'] as String),
    horaFin: DateTime.parse(map['hora_fin'] as String),
    duracion: Duration(minutes: map['duracion_minutos'] as int),
    categoriaId: map['categoria_id'] as int,
    subcategoriaId: map['subcategoria_id'] as int?,
    repeticion: repeticion,
    notas: map['notas'] as String?,
    notificacionInicio: (map['notificacion_inicio'] as int? ?? 0) == 1,
    minutosAntes: map['minutos_antes'] as int?,
    bloqueOriginalId: map['bloque_original_id'] as int?,
    plantillaId: map['plantilla_id'] as int?,
    completado: (map['completado'] as int? ?? 0) == 1,
  );
}
}