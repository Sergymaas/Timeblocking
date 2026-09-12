import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/bloque.dart';
import '../database/database_helper.dart';

import 'dart:io';

class NotificacionService {
  static final NotificacionService instance = NotificacionService._internal();
  factory NotificacionService() => instance;
  NotificacionService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;

  // ─── Inicialización ──────────────────────────────────────────────────────────

  Future<void> inicializar() async {
    if (_inicializado) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Abrir',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(initSettings);
    _inicializado = true;
  }

  // ─── Detalles de notificación ────────────────────────────────────────────────

  NotificationDetails _detalles() {
    const androidDetails = AndroidNotificationDetails(
      'time_blocking_channel',
      'Bloques de tiempo',
      channelDescription: 'Notificaciones de inicio de bloques de tiempo',
      importance: Importance.high,
      priority: Priority.high,
    );

    const linuxDetails = LinuxNotificationDetails();

    return const NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );
  }

  // ─── Programar notificaciones para un bloque ─────────────────────────────────

  Future<void> programarNotificaciones(Bloque bloque) async {
    await cancelarNotificaciones(bloque);

    if (bloque.id == null) return;

    // Notificación al inicio del bloque
    if (bloque.notificacionInicio) {
      await _programar(
        id: bloque.id! * 10,
        titulo: bloque.titulo,
        cuerpo: 'Empieza ahora',
        cuando: bloque.horaInicio,
      );
    }

    // Notificación X minutos antes
    if (bloque.minutosAntes != null && bloque.minutosAntes! > 0) {
      final cuando = bloque.horaInicio
          .subtract(Duration(minutes: bloque.minutosAntes!));
      if (cuando.isAfter(DateTime.now())) {
        await _programar(
          id: bloque.id! * 10 + 1,
          titulo: bloque.titulo,
          cuerpo: 'Empieza en ${bloque.minutosAntes} minutos',
          cuando: cuando,
        );
      }
    }
  }

  Future<void> _programar({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime cuando,
  }) async {
    if (cuando.isBefore(DateTime.now())) return;

    // zonedSchedule no está soportado en Linux
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) return;

    await _plugin.zonedSchedule(
      id,
      titulo,
      cuerpo,
      tz.TZDateTime.from(cuando, tz.local),
      _detalles(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Cancelar notificaciones de un bloque ────────────────────────────────────

  Future<void> cancelarNotificaciones(Bloque bloque) async {
    if (bloque.id == null) return;
    try {
      await _plugin.cancel(bloque.id! * 10);
      await _plugin.cancel(bloque.id! * 10 + 1);
    } catch (e) {
    }
  }

  // ─── Cancelar todas ──────────────────────────────────────────────────────────

  Future<void> cancelarTodas() async {
    await _plugin.cancelAll();
  }
  // ──── Reprogramar notificaciones ─────────────────────────────────────────────
  Future<void> reprogramarTodas() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final bloques = await DatabaseHelper.instance.obtenerBloquesConNotificacion();
      for (final bloque in bloques) {
        await programarNotificaciones(bloque);
      }
    } catch (e) {
    }
  }
}