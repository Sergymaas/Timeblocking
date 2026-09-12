import 'package:flutter/material.dart';
 
import '../database/database_helper.dart';
import '../models/subcategoria.dart';
 
class SubcategoriaProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
 
  List<Subcategoria> _subcategorias = [];
 
  // ─── Getters ────────────────────────────────────────────────────────────────
 
  List<Subcategoria> get subcategorias => _subcategorias;
 
  // ─── Cargar ─────────────────────────────────────────────────────────────────
 
  /// Si se pasa categoriaId, devuelve solo las subcategorías de esa categoría.
  Future<void> cargarSubcategorias({int? categoriaId}) async {
    _subcategorias = await _db.obtenerSubcategorias(categoriaId: categoriaId);
    notifyListeners();
  }
 
  // ─── Insertar ────────────────────────────────────────────────────────────────
 
  Future<void> insertarSubcategoria(Subcategoria subcategoria) async {
    await _db.insertarSubcategoria(subcategoria);
    await cargarSubcategorias(categoriaId: subcategoria.categoriaId);
  }
 
  // ─── Actualizar ──────────────────────────────────────────────────────────────
 
  Future<void> actualizarSubcategoria(Subcategoria subcategoria) async {
    await _db.actualizarSubcategoria(subcategoria);
    await cargarSubcategorias(categoriaId: subcategoria.categoriaId);
  }
 
  // ─── Eliminar ────────────────────────────────────────────────────────────────
 
  Future<void> eliminarSubcategoria(int id, int categoriaId) async {
    await _db.eliminarSubcategoria(id);
    await cargarSubcategorias(categoriaId: categoriaId);
  }
}