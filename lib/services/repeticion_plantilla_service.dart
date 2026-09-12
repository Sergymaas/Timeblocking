import '../database/database_helper.dart';
import '../models/bloque.dart';

class RepeticionPlantillaService {
  static final RepeticionPlantillaService instance =
      RepeticionPlantillaService._internal();
  factory RepeticionPlantillaService() => instance;
  RepeticionPlantillaService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // Ventana de generación: genera bloques hasta 30 días en el futuro
  static const int _diasVentana = 30;

  // ─── Registrar una nueva repetición ─────────────────────────────────────────

  Future<void> registrarRepeticion({
    required int plantillaId,
    required String frecuencia,
    required DateTime fechaInicio,
    required DateTime ultimaFechaGenerada,
    DateTime? fechaLimite,
  }) async {
    await _db.insertarRepeticionPlantilla({
      'plantilla_id': plantillaId,
      'frecuencia': frecuencia,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'ultima_fecha_generada': ultimaFechaGenerada.toIso8601String(),
      'fecha_limite': fechaLimite?.toIso8601String(),
    });
  }

  // ─── Procesar repeticiones pendientes ───────────────────────────────────────

  /// Llama esto al arrancar la app. Genera los bloques pendientes
  /// para todas las repeticiones activas hasta hoy + 30 días.
  Future<void> procesarRepeticionesPendientes() async {
    final repeticiones = await _db.obtenerRepeticionesPlantilla();
    final limite = _soloFecha(DateTime.now()).add(
      const Duration(days: _diasVentana),
    );

    for (final rep in repeticiones) {
      final id = rep['id'] as int;
      final plantillaId = rep['plantilla_id'] as int;
      final frecuencia = rep['frecuencia'] as String;
      final fechaLimite = rep['fecha_limite'] != null
        ? DateTime.parse(rep['fecha_limite'] as String)
        : null;
      DateTime ultimaGenerada =
          DateTime.parse(rep['ultima_fecha_generada'] as String);

      // Calcula la siguiente fecha a generar
      DateTime siguiente = _siguienteFecha(ultimaGenerada, frecuencia, plantillaId);

      // Genera bloques hasta el límite
      while (!siguiente.isAfter(limite)) {
        if (fechaLimite != null && siguiente.isAfter(fechaLimite)) break;
        
        await _generarBloques(plantillaId, siguiente, fechaLimite);
        await _db.actualizarUltimaFechaGenerada(id, siguiente);
        ultimaGenerada = siguiente;
        siguiente = _siguienteFecha(ultimaGenerada, frecuencia, plantillaId);
      }
    }
  }

  // ─── Generar bloques para una fecha ─────────────────────────────────────────

  Future<void> _generarBloques(int plantillaId, DateTime fechaInicio, DateTime? fechaLimite) async {
    final dias = await _db.obtenerDiasPlantilla(plantillaId);

    for (final dia in dias) {
      final fecha = fechaInicio.add(Duration(days: dia.numeroDia - 1));
      if (fechaLimite != null && fecha.isAfter(fechaLimite)) continue;
      final bloquesDia = await _db.obtenerBloquesPorDiaPlantilla(dia.id!);

      for (final bp in bloquesDia) {
        final horaInicio = DateTime(
          fecha.year, fecha.month, fecha.day,
          bp.horaInicioMinutos ~/ 60,
          bp.horaInicioMinutos % 60,
        );
        final horaFin = DateTime(
          fecha.year, fecha.month, fecha.day,
          bp.horaFinMinutos ~/ 60,
          bp.horaFinMinutos % 60,
        );

        // Verifica que no existe ya un bloque igual
        final existentes = await _db.obtenerBloquesPorDia(fecha);
        final yaExiste = existentes.any((b) =>
            b.titulo == bp.titulo &&
            b.horaInicio.hour == horaInicio.hour &&
            b.horaInicio.minute == horaInicio.minute);

        if (yaExiste) continue;

        final bloque = Bloque.desdeInicioYFin(
          titulo: bp.titulo,
          horaInicio: horaInicio,
          horaFin: horaFin,
          categoriaId: bp.categoriaId,
          subcategoriaId: bp.subcategoriaId,
          notas: bp.notas,
          plantillaId: plantillaId,
        );

        await _db.insertarBloque(bloque);
      }
    }
  }

  // ─── Calcular siguiente fecha ────────────────────────────────────────────────

  DateTime _siguienteFecha(
      DateTime ultima, String frecuencia, int plantillaId) {
    if (frecuencia == 'semanal') {
      return ultima.add(const Duration(days: 7));
    } else {
      // mensual
      return DateTime(ultima.year, ultima.month + 1, ultima.day);
    }
  }

  // ─── Eliminar repetición ─────────────────────────────────────────────────────

  Future<void> eliminarRepeticion(int plantillaId) async {
    await _db.eliminarRepeticionesPlantilla(plantillaId);
  }

  // ─── Helper ──────────────────────────────────────────────────────────────────

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
}