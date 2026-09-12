import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/plantilla.dart';
import '../models/dia_plantilla.dart';
import '../models/bloque_plantilla.dart';
import '../models/bloque.dart';

class PlantillaProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Plantilla> _plantillas = [];
  List<DiaPlantilla> _diasActuales = [];
  List<BloquePlantilla> _bloquesActuales = [];

  List<Plantilla> get plantillas => _plantillas;
  List<DiaPlantilla> get diasActuales => _diasActuales;
  List<BloquePlantilla> get bloquesActuales => _bloquesActuales;

  // ─── Plantillas ─────────────────────────────────────────────────────────────

  Future<void> cargarPlantillas() async {
    _plantillas = await _db.obtenerPlantillas();
    notifyListeners();
  }

  Future<int> insertarPlantilla(Plantilla plantilla) async {
    final id = await _db.insertarPlantilla(plantilla);

    // Crea automáticamente los días de la plantilla
    for (int i = 1; i <= plantilla.numeroDias; i++) {
      await _db.insertarDiaPlantilla(DiaPlantilla(
        plantillaId: id,
        numeroDia: i,
      ));
    }

    await cargarPlantillas();
    return id;
  }

  Future<void> actualizarPlantilla(Plantilla plantilla) async {
    await _db.actualizarPlantilla(plantilla);
    await cargarPlantillas();
  }

  Future<void> eliminarPlantilla(int id) async {
    await _db.eliminarPlantilla(id);
    await cargarPlantillas();
  }

  // ─── Días ───────────────────────────────────────────────────────────────────

  Future<void> cargarDias(int plantillaId) async {
    _diasActuales = await _db.obtenerDiasPlantilla(plantillaId);
    notifyListeners();
  }

  // ─── Bloques ────────────────────────────────────────────────────────────────

  Future<void> cargarBloques(int diaPlantillaId) async {
    _bloquesActuales =
        await _db.obtenerBloquesPorDiaPlantilla(diaPlantillaId);
    notifyListeners();
  }

  Future<void> insertarBloquePlantilla(BloquePlantilla bloque) async {
    await _db.insertarBloquePlantilla(bloque);
    await cargarBloques(bloque.diaPlantillaId);
  }

  Future<void> actualizarBloquePlantilla(BloquePlantilla bloque) async {
    await _db.actualizarBloquePlantilla(bloque);
    await cargarBloques(bloque.diaPlantillaId);
  }

  Future<void> eliminarBloquePlantilla(int id, int diaPlantillaId) async {
    await _db.eliminarBloquePlantilla(id);
    await cargarBloques(diaPlantillaId);
  }

  // ─── Aplicar plantilla ───────────────────────────────────────────────────────

  /// Devuelve los bloques que se solaparían con los existentes.
  Future<List<BloquePlantilla>> verificarSolapamientos(
    int plantillaId,
    DateTime fechaInicio,
  ) async {
    final dias = await _db.obtenerDiasPlantilla(plantillaId);
    final solapados = <BloquePlantilla>[];

    for (final dia in dias) {
      final fecha = fechaInicio.add(Duration(days: dia.numeroDia - 1));
      final bloquesExistentes = await _db.obtenerBloquesPorDia(fecha);
      final bloquesDia =
          await _db.obtenerBloquesPorDiaPlantilla(dia.id!);

      for (final bp in bloquesDia) {
        final inicioNuevo = DateTime(
          fecha.year, fecha.month, fecha.day,
          bp.horaInicioMinutos ~/ 60,
          bp.horaInicioMinutos % 60,
        );
        final finNuevo = DateTime(
          fecha.year, fecha.month, fecha.day,
          bp.horaFinMinutos ~/ 60,
          bp.horaFinMinutos % 60,
        );

        final solapa = bloquesExistentes.any((be) =>
            be.horaInicio.isBefore(finNuevo) &&
            be.horaFin.isAfter(inicioNuevo));

        if (solapa) solapados.add(bp);
      }
    }

    return solapados;
  }

  /// Aplica la plantilla copiando bloques a partir de fechaInicio.
  Future<void> aplicarPlantilla(
    int plantillaId,
    DateTime fechaInicio,
    {DateTime? fechaLimite}
  ) async {
    
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

        final bloque = Bloque.desdeInicioYFin(
          titulo: bp.titulo,
          horaInicio: horaInicio,
          horaFin: horaFin,
          categoriaId: bp.categoriaId,
          subcategoriaId: bp.subcategoriaId,
          notas: bp.notas,
          plantillaId: plantillaId,
        );

        
        final existentes = await _db.obtenerBloquesPorDia(fecha);
        final yaExiste = existentes.any((b) =>
            b.plantillaId == plantillaId &&
            b.horaInicio.hour == horaInicio.hour &&
            b.horaInicio.minute == horaInicio.minute);

        if (yaExiste) continue;

        await _db.insertarBloque(bloque);
      }
    }
  }
}