import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';

import '../services/calendario_service.dart';

class CalendarioProvider extends ChangeNotifier {
  final CalendarioService _service = CalendarioService.instance;

  List<Calendar> _calendarios = [];
  Set<String> _calendariosActivos = {};
  List<EventoCalendario> _eventosDelDia = [];
  bool _permisoConcedido = false;
  bool _cargando = false;

  List<Calendar> get calendarios => _calendarios;
  Set<String> get calendariosActivos => _calendariosActivos;
  List<EventoCalendario> get eventosDelDia => _eventosDelDia;
  bool get permisoConcedido => _permisoConcedido;
  bool get cargando => _cargando;

  // ─── Inicializar y solicitar permisos ────────────────────────────────────────

  Future<void> inicializar() async {
    _permisoConcedido = await _service.solicitarPermisos();
    if (_permisoConcedido) {
      await cargarCalendarios();
    }
    notifyListeners();
  }

  // ─── Cargar calendarios disponibles ─────────────────────────────────────────

  Future<void> cargarCalendarios() async {
    _calendarios = await _service.obtenerCalendarios();

    // Activa todos los calendarios por defecto
    if (_calendariosActivos.isEmpty) {
      _calendariosActivos = _calendarios
          .where((c) => c.id != null)
          .map((c) => c.id!)
          .toSet();
    }

    notifyListeners();
  }

  // ─── Activar/desactivar calendario ───────────────────────────────────────────

  void toggleCalendario(String id) {
    if (_calendariosActivos.contains(id)) {
      _calendariosActivos.remove(id);
    } else {
      _calendariosActivos.add(id);
    }
    notifyListeners();
  }

  // ─── Cargar eventos de un día ────────────────────────────────────────────────

  Future<void> cargarEventos(DateTime dia) async {
    if (!_permisoConcedido) return;

    _cargando = true;
    notifyListeners();

    _eventosDelDia = await _service.obtenerEventosPorDia(
      dia,
      _calendariosActivos.toList(),
    );

    _cargando = false;
    notifyListeners();
  }
}