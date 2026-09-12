import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/bloque.dart';
import '../services/notificacion_service.dart';

class BloqueProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Bloque> _bloques = [];
  DateTime _diaSeleccionado = DateTime.now();
  final Map<String, List<Bloque>> _cache = {};

  List<Bloque> get bloques => _bloques;
  DateTime get diaSeleccionado => _diaSeleccionado;

  String _key(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day).toIso8601String();

  // ─── Cargar bloques de un día ──────────────────────────────────────────────

  Future<void> cargarBloques(DateTime dia) async {
    _diaSeleccionado = dia;
    final key = _key(dia);
    if (_cache.containsKey(key)) {
      _bloques = _cache[key]!;
      _limpiarCacheAntigua();
      notifyListeners();
      return;
    }
    _bloques = await _db.obtenerBloquesPorDia(dia);
    _cache[key] = _bloques;
    notifyListeners();
  }

  void invalidarCache() {
    _cache.clear();
    notifyListeners();
  }

  int _version = 0;
  int get version => _version;

  void _incrementarVersion() {
    _version++;
    notifyListeners();
  }

  void _limpiarCacheAntigua() {
    if (_cache.length <= 30) return;
    final keys = _cache.keys.toList()..sort();
    final keysAEliminar = keys.take(_cache.length - 30);
    for (final key in keysAEliminar) {
      _cache.remove(key);
    }
  }

  // ─── Insertar ──────────────────────────────────────────────────────────────

  Future<void> insertarBloque(Bloque bloque) async {
    final id = await _db.insertarBloque(bloque);
    final bloqueConId = Bloque.desdeInicioYFin(
      id: id,
      titulo: bloque.titulo,
      horaInicio: bloque.horaInicio,
      horaFin: bloque.horaFin,
      categoriaId: bloque.categoriaId,
      subcategoriaId: bloque.subcategoriaId,
      repeticion: bloque.repeticion,
      notas: bloque.notas,
      notificacionInicio: bloque.notificacionInicio,
      minutosAntes: bloque.minutosAntes,
      bloqueOriginalId: bloque.bloqueOriginalId,
    );
    await NotificacionService.instance.programarNotificaciones(bloqueConId);
    _cache.remove(_key(bloque.horaInicio));
    await cargarBloques(_diaSeleccionado);
    _incrementarVersion();
  }

  // ─── Actualizar ────────────────────────────────────────────────────────────

  Future<void> actualizarBloque(Bloque bloque) async {
    await _db.actualizarBloque(bloque);
    await NotificacionService.instance.programarNotificaciones(bloque);
    _cache.remove(_key(bloque.horaInicio));
    await cargarBloques(_diaSeleccionado);
    _incrementarVersion();
  }

  // ─── Mover ────────────────────────────────────────────────────────────────

  Future<void> moverBloque(Bloque bloque, DateTime nuevaHoraInicio) async {
    final bloqueMovido = bloque.moverA(nuevaHoraInicio);
    await actualizarBloque(bloqueMovido);
  }

  // ─── Eliminar ─────────────────────────────────────────────────────────────

  Future<void> eliminarBloque(int id) async {
    final bloque = _bloques.firstWhere((b) => b.id == id);
    await NotificacionService.instance.cancelarNotificaciones(bloque);
    await _db.eliminarBloque(id);
    _cache.remove(_key(bloque.horaInicio));
    await cargarBloques(_diaSeleccionado);
    _incrementarVersion();
  }

  // ─── Actualizar bloques siguientes ─────────────────────────────────────────────────────────────

  Future<void> actualizarBloqueYSiguientes(
      Bloque bloqueEditado) async {
    // Actualiza el bloque actual
    await _db.actualizarBloque(bloqueEditado);

    if (bloqueEditado.plantillaId == null) return;

    // Obtiene todos los bloques siguientes de la misma plantilla
    final siguientes = await _db.obtenerBloquesPorPlantillaDesde(
      bloqueEditado.plantillaId!,
      bloqueEditado.horaInicio.add(const Duration(days: 1)),
    );

    for (final b in siguientes) {
      // Calcula la nueva hora manteniendo la misma hora del día
      final nuevaInicio = DateTime(
        b.horaInicio.year,
        b.horaInicio.month,
        b.horaInicio.day,
        bloqueEditado.horaInicio.hour,
        bloqueEditado.horaInicio.minute,
      );
      final nuevaFin = DateTime(
        b.horaFin.year,
        b.horaFin.month,
        b.horaFin.day,
        bloqueEditado.horaFin.hour,
        bloqueEditado.horaFin.minute,
      );

      final bloqueActualizado = Bloque.desdeInicioYFin(
        id: b.id,
        titulo: bloqueEditado.titulo,
        horaInicio: nuevaInicio,
        horaFin: nuevaFin,
        categoriaId: bloqueEditado.categoriaId,
        subcategoriaId: bloqueEditado.subcategoriaId,
        repeticion: b.repeticion,
        notas: bloqueEditado.notas,
        notificacionInicio: bloqueEditado.notificacionInicio,
        minutosAntes: bloqueEditado.minutosAntes,
        bloqueOriginalId: b.bloqueOriginalId,
        plantillaId: b.plantillaId,
      );

      await _db.actualizarBloque(bloqueActualizado);
    }

    invalidarCache();
    await cargarBloques(_diaSeleccionado);
    _incrementarVersion();
  }

// ─── Completar bloques ─────────────────────────────────────────────────────────────

  Future<void> completarBloque(Bloque bloque, DateTime horaFin) async {
  // Marca el bloque como completado con la hora actual como fin
    final bloqueCompletado = Bloque.desdeInicioYFin(
      id: bloque.id,
      titulo: bloque.titulo,
      horaInicio: bloque.horaInicio,
      horaFin: horaFin,
      categoriaId: bloque.categoriaId,
      subcategoriaId: bloque.subcategoriaId,
      repeticion: bloque.repeticion,
      notas: bloque.notas,
      notificacionInicio: bloque.notificacionInicio,
      minutosAntes: bloque.minutosAntes,
      bloqueOriginalId: bloque.bloqueOriginalId,
      plantillaId: bloque.plantillaId,
      completado: true,
    );
    await _db.actualizarBloque(bloqueCompletado);

    invalidarCache();
    await cargarBloques(_diaSeleccionado);
  }

  Future<void> descompletarBloque(Bloque bloque) async {
    final bloqueDescompletado = Bloque.desdeInicioYFin(
      id: bloque.id,
      titulo: bloque.titulo,
      horaInicio: bloque.horaInicio,
      horaFin: bloque.horaFin,
      categoriaId: bloque.categoriaId,
      subcategoriaId: bloque.subcategoriaId,
      repeticion: bloque.repeticion,
      notas: bloque.notas,
      notificacionInicio: bloque.notificacionInicio,
      minutosAntes: bloque.minutosAntes,
      bloqueOriginalId: bloque.bloqueOriginalId,
      plantillaId: bloque.plantillaId,
      completado: false,
    );
    await _db.actualizarBloque(bloqueDescompletado);
    invalidarCache();
    await cargarBloques(_diaSeleccionado);
  }

}