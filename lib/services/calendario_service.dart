import 'dart:io';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';

class EventoCalendario {
  final String id;
  final String titulo;
  final DateTime inicio;
  final DateTime fin;
  final Color color;

  const EventoCalendario({
    required this.id,
    required this.titulo,
    required this.inicio,
    required this.fin,
    required this.color,
  });
}

class CalendarioService {
  static final CalendarioService instance = CalendarioService._internal();
  factory CalendarioService() => instance;
  CalendarioService._internal();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  List<Calendar> _calendarios = [];

  // ─── Inicialización y permisos ───────────────────────────────────────────────

  Future<bool> solicitarPermisos() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    var resultado = await _plugin.hasPermissions();
    if (resultado.isSuccess && resultado.data == true) return true;

    resultado = await _plugin.requestPermissions();
    return resultado.isSuccess && resultado.data == true;
  }

  // ─── Cargar calendarios disponibles ─────────────────────────────────────────

  Future<List<Calendar>> obtenerCalendarios() async {
    if (!Platform.isAndroid && !Platform.isIOS) return [];

    final resultado = await _plugin.retrieveCalendars();
    if (resultado.isSuccess && resultado.data != null) {
      _calendarios = resultado.data!;
    }
    return _calendarios;
  }

  // ─── Obtener eventos de un día ───────────────────────────────────────────────

  Future<List<EventoCalendario>> obtenerEventosPorDia(
    DateTime dia,
    List<String> calendarioIds,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) return [];
    if (calendarioIds.isEmpty) return [];

    final inicio = DateTime(dia.year, dia.month, dia.day, 0, 0, 0);
    final fin = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);

    final eventos = <EventoCalendario>[];

    for (final calId in calendarioIds) {
      final resultado = await _plugin.retrieveEvents(
        calId,
        RetrieveEventsParams(startDate: inicio, endDate: fin),
      );

      if (!resultado.isSuccess || resultado.data == null) continue;

      final calendario = _calendarios
          .where((c) => c.id == calId)
          .firstOrNull;

      final colorCalendario = calendario?.color != null
          ? Color(calendario!.color!)
          : Colors.grey;

      for (final evento in resultado.data!) {
        if (evento.title == null) continue;
        if (evento.start == null || evento.end == null) continue;

        eventos.add(EventoCalendario(
          id: evento.eventId ?? '',
          titulo: evento.title!,
          inicio: evento.start!,
          fin: evento.end!,
          color: colorCalendario,
        ));
      }
    }

    eventos.sort((a, b) => a.inicio.compareTo(b.inicio));
    return eventos;
  }
}