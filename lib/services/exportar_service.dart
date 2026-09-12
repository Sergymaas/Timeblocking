import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/bloque.dart';
import '../models/categoria.dart';

class ExportarService {
  static final ExportarService instance = ExportarService._internal();
  factory ExportarService() => instance;
  ExportarService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─── Exportar JSON ───────────────────────────────────────────────────────────

  Future<void> exportarJSON(BuildContext context) async {
    final categorias = await _db.obtenerCategorias();
    final bloques = await _obtenerTodosBloques();

    final datos = {
      'version': 1,
      'exportado': DateTime.now().toIso8601String(),
      'categorias': categorias.map((c) => {
        'id': c.id,
        'nombre': c.nombre,
        'color': c.color.value,
      }).toList(),
      'bloques': bloques.map((b) => b.toMap()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(datos);
    await _compartirArchivo(
      contenido: json,
      nombre: 'timeblocking_${_fechaArchivo()}.json',
      mime: 'application/json',
    );
  }

  // ─── Exportar CSV ────────────────────────────────────────────────────────────

  Future<void> exportarCSV(BuildContext context) async {
    final categorias = await _db.obtenerCategorias();
    final bloques = await _obtenerTodosBloques();

    final categoriaMap = {for (final c in categorias) c.id!: c.nombre};

    final buffer = StringBuffer();
    buffer.writeln(
        'id,titulo,hora_inicio,hora_fin,duracion_minutos,categoria,notas,repeticion_frecuencia,repeticion_dias,notificacion_inicio,minutos_antes');

    for (final b in bloques) {
      buffer.writeln([
        b.id,
        _escaparCSV(b.titulo),
        b.horaInicio.toIso8601String(),
        b.horaFin.toIso8601String(),
        b.duracion.inMinutes,
        _escaparCSV(categoriaMap[b.categoriaId] ?? ''),
        _escaparCSV(b.notas ?? ''),
        b.repeticion?.frecuencia.name ?? '',
        b.repeticion?.dias.join(';') ?? '',
        b.notificacionInicio ? 1 : 0,
        b.minutosAntes ?? '',
      ].join(','));
    }

    await _compartirArchivo(
      contenido: buffer.toString(),
      nombre: 'timeblocking_${_fechaArchivo()}.csv',
      mime: 'text/csv',
    );
  }

  // ─── Importar JSON ───────────────────────────────────────────────────────────

  Future<ImportarResultado> importarJSON() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (resultado == null || resultado.files.isEmpty) {
      return ImportarResultado.cancelado();
    }

    try {
      final archivo = File(resultado.files.single.path!);
      final contenido = await archivo.readAsString();
      final datos = jsonDecode(contenido) as Map<String, dynamic>;

      final categorias = (datos['categorias'] as List).map((c) {
        return Categoria(
          nombre: c['nombre'] as String,
          color: Color(c['color'] as int),
        );
      }).toList();

      // Inserta categorías y construye mapa de ids antiguos a nuevos
      final mapaIds = <int, int>{};
      final categoriasExistentes = await _db.obtenerCategorias();

      for (int i = 0; i < categorias.length; i++) {
        final idAntiguo = (datos['categorias'][i]['id'] as int);
        final nombre = categorias[i].nombre;

        // Busca si ya existe una categoría con ese nombre
        final existente = categoriasExistentes
            .where((c) => c.nombre.toLowerCase() == nombre.toLowerCase())
            .firstOrNull;

        if (existente != null) {
          // Usa la existente, no inserta duplicado
          mapaIds[idAntiguo] = existente.id!;
        } else {
          // Inserta nueva
          final idNuevo = await _db.insertarCategoria(categorias[i]);
          mapaIds[idAntiguo] = idNuevo;
        }
      }

      // Inserta bloques con los nuevos ids de categoría
      final bloquesExistentes = await _obtenerTodosBloques();

      int bloquesImportados = 0;
      for (final b in (datos['bloques'] as List)) {
        final map = Map<String, dynamic>.from(b as Map);
        final idCategoriaAntiguo = map['categoria_id'] as int;
        map['id'] = null;
        map['categoria_id'] = mapaIds[idCategoriaAntiguo] ?? idCategoriaAntiguo;

        final bloque = Bloque.fromMap(map);

        // Comprueba si ya existe un bloque igual
        final existe = bloquesExistentes.any((e) =>
            e.titulo == bloque.titulo &&
            e.horaInicio == bloque.horaInicio &&
            e.horaFin == bloque.horaFin);

        if (!existe) {
          await _db.insertarBloque(bloque);
          bloquesImportados++;
        }
      }
      final categoriasActuales = await _db.obtenerCategorias();

      return ImportarResultado.exito(
        categorias: categorias.length,
        bloques: bloquesImportados,
      );
    } catch (e) {
      return ImportarResultado.error(e.toString());
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<List<Bloque>> _obtenerTodosBloques() async {
    final db = await _db.database;
    final maps = await db.query('bloques', orderBy: 'hora_inicio ASC');
    return maps.map((m) => Bloque.fromMap(m)).toList();
  }

  Future<void> _compartirArchivo({
    required String contenido,
    required String nombre,
    required String mime,
  }) async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // En desktop, guardar directamente con file picker
      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo',
        fileName: nombre,
      );
      if (ruta == null) return;
      await File(ruta).writeAsString(contenido);
    } else {
      // En Android/iOS, compartir
      final dir = await getTemporaryDirectory();
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsString(contenido);
      await Share.shareXFiles(
        [XFile(archivo.path, mimeType: mime)],
        subject: nombre,
      );
    }
  }

  String _escaparCSV(String valor) {
    if (valor.contains(',') || valor.contains('"') || valor.contains('\n')) {
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }

  String _fechaArchivo() {
    final ahora = DateTime.now();
    return '${ahora.year}${ahora.month.toString().padLeft(2, '0')}${ahora.day.toString().padLeft(2, '0')}';
  }
}

// ─── Resultado de importación ─────────────────────────────────────────────────

class ImportarResultado {
  final bool exito;
  final bool cancelado;
  final int categorias;
  final int bloques;
  final String? error;

  const ImportarResultado._({
    required this.exito,
    required this.cancelado,
    this.categorias = 0,
    this.bloques = 0,
    this.error,
  });

  factory ImportarResultado.exito({
    required int categorias,
    required int bloques,
  }) =>
      ImportarResultado._(exito: true, cancelado: false,
          categorias: categorias, bloques: bloques);

  factory ImportarResultado.cancelado() =>
      ImportarResultado._(exito: false, cancelado: true);

  factory ImportarResultado.error(String mensaje) =>
      ImportarResultado._(exito: false, cancelado: false, error: mensaje);
}