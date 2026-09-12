import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
 
import '../models/bloque.dart';
import '../models/categoria.dart';
import '../models/subcategoria.dart';
import '../models/repeticion.dart';
import '../models/plantilla.dart';
import '../models/dia_plantilla.dart';
import '../models/bloque_plantilla.dart';
import '../utils/fecha_utils.dart';
import '../database/database_helper.dart';
 
class DatabaseHelper {
  // Singleton: solo existe una instancia de DatabaseHelper en toda la app.
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();
 
  static Database? _database;
 
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
 
  // ─── Inicialización ─────────────────────────────────────────────────────────
 
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'timetune.db');
 
    return await openDatabase(
      path,
      version: 1,
      onCreate: _crearTablas,
    );
  }
 
  Future<void> _crearTablas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categorias (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre  TEXT    NOT NULL,
        color   INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subcategorias (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre       TEXT    NOT NULL,
        categoria_id INTEGER NOT NULL,
        FOREIGN KEY (categoria_id) REFERENCES categorias (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bloques (
        id                     INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo                 TEXT    NOT NULL,
        hora_inicio            TEXT    NOT NULL,
        hora_fin               TEXT    NOT NULL,
        duracion_minutos       INTEGER NOT NULL,
        categoria_id           INTEGER NOT NULL,
        subcategoria_id        INTEGER,
        repeticion_frecuencia  INTEGER,
        repeticion_dias        TEXT,
        notas                  TEXT,
        notificacion_inicio  INTEGER NOT NULL DEFAULT 0,
        minutos_antes        INTEGER,
        bloque_original_id   INTEGER,
        plantilla_id         INTEGER,
        completado           INTEGER NOT NULL DEFAULT 0,
        repeticion_fecha_limite  TEXT,
        FOREIGN KEY (categoria_id)    REFERENCES categorias    (id),
        FOREIGN KEY (subcategoria_id) REFERENCES subcategorias (id)
      )
    ''');

    await db.execute('''
    CREATE TABLE plantillas (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre       TEXT    NOT NULL,
      numero_dias  INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE dias_plantilla (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      plantilla_id  INTEGER NOT NULL,
      numero_dia    INTEGER NOT NULL,
      FOREIGN KEY (plantilla_id) REFERENCES plantillas (id)
    )
  ''');

  await db.execute('''
    CREATE TABLE bloques_plantilla (
      id                   INTEGER PRIMARY KEY AUTOINCREMENT,
      dia_plantilla_id     INTEGER NOT NULL,
      titulo               TEXT    NOT NULL,
      hora_inicio_minutos  INTEGER NOT NULL,
      hora_fin_minutos     INTEGER NOT NULL,
      categoria_id         INTEGER NOT NULL,
      subcategoria_id      INTEGER,
      notas                TEXT,
      FOREIGN KEY (dia_plantilla_id) REFERENCES dias_plantilla (id),
      FOREIGN KEY (categoria_id)     REFERENCES categorias      (id)
    )
  ''');

  await db.execute('''
    CREATE TABLE repeticiones_plantilla (
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      plantilla_id          INTEGER NOT NULL,
      frecuencia            TEXT    NOT NULL,
      fecha_inicio          TEXT    NOT NULL,
      ultima_fecha_generada TEXT    NOT NULL,
      fecha_limite  TEXT,
      FOREIGN KEY (plantilla_id) REFERENCES plantillas (id)
    )
  ''');

    await _insertarCategoriasPredefinidas(db);
  }

  Future<void> _insertarCategoriasPredefinidas(Database db) async {
  final categorias = [
    {'nombre': 'Trabajo',        'color': 0xFF1565C0},
    {'nombre': 'Tiempo libre',   'color': 0xFF2E7D32},
    {'nombre': 'Deporte',        'color': 0xFFE65100},
    {'nombre': 'Desplazamiento', 'color': 0xFF6A1B9A},
    {'nombre': 'Comida',         'color': 0xFFEF6C00},
    {'nombre': 'Cena',           'color': 0xFF4E342E},
    {'nombre': 'Dormir',         'color': 0xFF37474F},
  ];

  for (final c in categorias) {
    await db.insert('categorias', c);
  }
}
 
  // ─── Categorías ─────────────────────────────────────────────────────────────
 
  Future<int> insertarCategoria(Categoria categoria) async {
    final db = await database;
    return await db.insert('categorias', categoria.toMap());
  }
 
  Future<List<Categoria>> obtenerCategorias() async {
    final db = await database;
    final maps = await db.query('categorias');
    return maps.map((m) => Categoria.fromMap(m)).toList();
  }
 
  Future<int> actualizarCategoria(Categoria categoria) async {
    final db = await database;
    return await db.update(
      'categorias',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }
 
  Future<int> eliminarCategoria(int id) async {
    final db = await database;
    return await db.delete(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
 
  // ─── Subcategorías ──────────────────────────────────────────────────────────
 
  Future<int> insertarSubcategoria(Subcategoria subcategoria) async {
    final db = await database;
    return await db.insert('subcategorias', subcategoria.toMap());
  }
 
  Future<List<Subcategoria>> obtenerSubcategorias({int? categoriaId}) async {
    final db = await database;
    final maps = await db.query(
      'subcategorias',
      where: categoriaId != null ? 'categoria_id = ?' : null,
      whereArgs: categoriaId != null ? [categoriaId] : null,
    );
    return maps.map((m) => Subcategoria.fromMap(m)).toList();
  }
 
  Future<int> actualizarSubcategoria(Subcategoria subcategoria) async {
    final db = await database;
    return await db.update(
      'subcategorias',
      subcategoria.toMap(),
      where: 'id = ?',
      whereArgs: [subcategoria.id],
    );
  }
 
  Future<int> eliminarSubcategoria(int id) async {
    final db = await database;
    return await db.delete(
      'subcategorias',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
 
  // ─── Bloques ────────────────────────────────────────────────────────────────
 
  Future<int> insertarBloque(Bloque bloque) async {
    final db = await database;
    return await db.insert('bloques', bloque.toMap());
  }
 
  /// Devuelve todos los bloques de un día concreto.
  Future<List<Bloque>> obtenerBloquesPorDia(DateTime dia) async {
    final db = await database;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);

    // Bloques del día concreto
    final maps = await db.query(
      'bloques',
      where: 'hora_inicio >= ? AND hora_inicio <= ?',
      whereArgs: [inicio.toIso8601String(), fin.toIso8601String()],
      orderBy: 'hora_inicio ASC',
    );
    final bloquesDia = maps.map((m) => Bloque.fromMap(m)).toList();

    // Comprueba si hay bloques con repetición antes de buscarlos
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bloques WHERE repeticion_frecuencia IS NOT NULL'
    );
    if ((countResult.first['count'] as int) == 0) return bloquesDia;

    // Bloques con repetición fuera de este día
    final mapsRepetidos = await db.query(
      'bloques',
      where: 'repeticion_frecuencia IS NOT NULL AND hora_inicio < ?',
      whereArgs: [inicio.toIso8601String()],
    );

    final ocurrencias = <Bloque>[];

    for (final map in mapsRepetidos) {
      final bloque = Bloque.fromMap(map);
      if (bloque.repeticion == null) continue;

      final corresponde = _correspondeAlDia(bloque, dia);
      if (!corresponde) continue;

      // Comprueba que no existe ya un bloque individual para este día
      // (ocurrencia editada individualmente)
      final yaExiste = bloquesDia.any((b) =>
          b.bloqueOriginalId == bloque.id ||
          (b.horaInicio.hour == bloque.horaInicio.hour &&
              b.horaInicio.minute == bloque.horaInicio.minute &&
              b.horaFin.hour == bloque.horaFin.hour &&
              b.horaFin.minute == bloque.horaFin.minute));
      
      if (yaExiste) continue;

      // Genera la ocurrencia con las fechas ajustadas al día
      final nuevaInicio = DateTime(
        dia.year, dia.month, dia.day,
        bloque.horaInicio.hour,
        bloque.horaInicio.minute,
      );
      final nuevaFin = DateTime(
        dia.year, dia.month, dia.day,
        bloque.horaFin.hour,
        bloque.horaFin.minute,
      );

      ocurrencias.add(Bloque.desdeInicioYFin(
        id: bloque.id,
        titulo: bloque.titulo,
        horaInicio: nuevaInicio,
        horaFin: nuevaFin,
        categoriaId: bloque.categoriaId,
        subcategoriaId: bloque.subcategoriaId,
        repeticion: bloque.repeticion,
        notas: bloque.notas,
        notificacionInicio: bloque.notificacionInicio,
        minutosAntes: bloque.minutosAntes,
        esOcurrencia: true,
        bloqueOriginalId: bloque.id,
      ));
    }

    final todos = [...bloquesDia, ...ocurrencias];
    todos.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    return todos;
  }

  bool _correspondeAlDia(Bloque bloque, DateTime dia) {
    final rep = bloque.repeticion!;
    if (rep.fechaLimite != null && dia.isAfter(rep.fechaLimite!)) return false;
    final diaOriginal = bloque.horaInicio;

    switch (rep.frecuencia) {
      case Frecuencia.diaria:
        return dia.isAfter(diaOriginal) || FechaUtils.mismodia(dia, diaOriginal);

      case Frecuencia.semanal:
        final diasDesde = dia.difference(
                DateTime(diaOriginal.year, diaOriginal.month, diaOriginal.day))
            .inDays;
        return diasDesde > 0 && diasDesde % 7 == 0;

      case Frecuencia.bisemanal:
        final diasDesde = dia.difference(
                DateTime(diaOriginal.year, diaOriginal.month, diaOriginal.day))
            .inDays;
        return diasDesde > 0 && diasDesde % 14 == 0;

      case Frecuencia.mensual:
        return dia.day == diaOriginal.day &&
            (dia.year > diaOriginal.year ||
                (dia.year == diaOriginal.year &&
                    dia.month > diaOriginal.month));
    }
  }
 
  Future<int> actualizarBloque(Bloque bloque) async {
    final db = await database;
    return await db.update(
      'bloques',
      bloque.toMap(),
      where: 'id = ?',
      whereArgs: [bloque.id],
    );
  }
 
  Future<int> eliminarBloque(int id) async {
    final db = await database;
    return await db.delete(
      'bloques',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Plantillas ──────────────────────────────────────────────────────────────

  Future<int> insertarPlantilla(Plantilla plantilla) async {
    final db = await database;
    return await db.insert('plantillas', plantilla.toMap());
  }

  Future<List<Plantilla>> obtenerPlantillas() async {
    final db = await database;
    final maps = await db.query('plantillas', orderBy: 'nombre ASC');
    return maps.map((m) => Plantilla.fromMap(m)).toList();
  }

  Future<int> actualizarPlantilla(Plantilla plantilla) async {
    final db = await database;
    return await db.update(
      'plantillas',
      plantilla.toMap(),
      where: 'id = ?',
      whereArgs: [plantilla.id],
    );
  }

  Future<void> eliminarPlantilla(int id) async {
    final db = await database;
    // Elimina en cascada
    final dias = await obtenerDiasPlantilla(id);
    for (final dia in dias) {
      await eliminarDiaPlantilla(dia.id!);
    }
    await db.delete('plantillas', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Días de plantilla ───────────────────────────────────────────────────────

  Future<int> insertarDiaPlantilla(DiaPlantilla dia) async {
    final db = await database;
    return await db.insert('dias_plantilla', dia.toMap());
  }

  Future<List<DiaPlantilla>> obtenerDiasPlantilla(int plantillaId) async {
    final db = await database;
    final maps = await db.query(
      'dias_plantilla',
      where: 'plantilla_id = ?',
      whereArgs: [plantillaId],
      orderBy: 'numero_dia ASC',
    );
    return maps.map((m) => DiaPlantilla.fromMap(m)).toList();
  }

  Future<void> eliminarDiaPlantilla(int id) async {
    final db = await database;
    await db.delete('bloques_plantilla',
        where: 'dia_plantilla_id = ?', whereArgs: [id]);
    await db.delete('dias_plantilla', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Bloques de plantilla ────────────────────────────────────────────────────

  Future<int> insertarBloquePlantilla(BloquePlantilla bloque) async {
    final db = await database;
    return await db.insert('bloques_plantilla', bloque.toMap());
  }

  Future<List<BloquePlantilla>> obtenerBloquesPorDiaPlantilla(
      int diaPlantillaId) async {
    final db = await database;
    final maps = await db.query(
      'bloques_plantilla',
      where: 'dia_plantilla_id = ?',
      whereArgs: [diaPlantillaId],
      orderBy: 'hora_inicio_minutos ASC',
    );
    return maps.map((m) => BloquePlantilla.fromMap(m)).toList();
  }

  Future<int> actualizarBloquePlantilla(BloquePlantilla bloque) async {
    final db = await database;
    return await db.update(
      'bloques_plantilla',
      bloque.toMap(),
      where: 'id = ?',
      whereArgs: [bloque.id],
    );
  }

  Future<void> eliminarBloquePlantilla(int id) async {
    final db = await database;
    await db.delete('bloques_plantilla', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Repeticiones de plantilla ───────────────────────────────────────────────

  Future<int> insertarRepeticionPlantilla(Map<String, dynamic> datos) async {
    final db = await database;
    return await db.insert('repeticiones_plantilla', datos);
  }

  Future<List<Map<String, dynamic>>> obtenerRepeticionesPlantilla() async {
    final db = await database;
    return await db.query('repeticiones_plantilla');
  }

  Future<void> actualizarUltimaFechaGenerada(int id, DateTime fecha) async {
    final db = await database;
    await db.update(
      'repeticiones_plantilla',
      {'ultima_fecha_generada': fecha.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> eliminarRepeticionesPlantilla(int plantillaId) async {
    final db = await database;
    await db.delete(
      'repeticiones_plantilla',
      where: 'plantilla_id = ?',
      whereArgs: [plantillaId],
    );
  }

  // ─── Sobreescribir días de plantilla ───────────────────────────────────────────────

  Future<List<Bloque>> obtenerBloquesPorPlantillaDesde(
      int plantillaId, DateTime desde) async {
    final db = await database;
    final maps = await db.query(
      'bloques',
      where: 'plantilla_id = ? AND hora_inicio >= ?',
      whereArgs: [plantillaId, desde.toIso8601String()],
      orderBy: 'hora_inicio ASC',
    );
    return maps.map((m) => Bloque.fromMap(m)).toList();
  }

  Future<void> eliminarBloquesPorPlantillaYDia(
      int plantillaId, DateTime dia) async {
    final db = await database;
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);
    await db.delete(
      'bloques',
      where:
          'plantilla_id = ? AND hora_inicio >= ? AND hora_inicio <= ?',
      whereArgs: [
        plantillaId,
        inicio.toIso8601String(),
        fin.toIso8601String(),
      ],
    );
  }

  Future<List<Bloque>> obtenerBloquesConNotificacion() async {
    final db = await database;
    final ahora = DateTime.now().toIso8601String();
    final maps = await db.query(
      'bloques',
      where: '(notificacion_inicio = 1 OR minutos_antes IS NOT NULL) AND hora_inicio > ?',
      whereArgs: [ahora],
    );
    return maps.map((m) => Bloque.fromMap(m)).toList();
  }
}