class FechaUtils {
  FechaUtils._(); // clase no instanciable

  static const List<String> _dias = [
    'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'
  ];

  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  static const List<String> _mesesCortos = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  /// Devuelve solo la fecha sin hora: 2026-05-11 00:00:00.000
  static DateTime soloFecha(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Formatea: "lun 11 mayo"
  static String formatearFecha(DateTime fecha) {
    return '${_dias[fecha.weekday - 1]} ${fecha.day} ${_meses[fecha.month - 1]}';
  }

  /// Formatea: "lun 11 may"
  static String formatearFechaCorta(DateTime fecha) {
    return '${_dias[fecha.weekday - 1]} ${fecha.day} ${_mesesCortos[fecha.month - 1]}';
  }

  /// Formatea hora: "09:30"
  static String formatearHora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Comprueba si dos fechas son el mismo día
  static bool mismodia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}