import 'package:flutter/material.dart';
 
import '../database/database_helper.dart';
import '../models/categoria.dart';
 
class CategoriaProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
 
  List<Categoria> _categorias = [];
 
  // ─── Getters ────────────────────────────────────────────────────────────────
 
  List<Categoria> get categorias => _categorias;
 
  // ─── Cargar ─────────────────────────────────────────────────────────────────
 
  Future<void> cargarCategorias() async {
    _categorias = await _db.obtenerCategorias();
    notifyListeners();
  }
 
  // ─── Insertar ────────────────────────────────────────────────────────────────
 
  Future<void> insertarCategoria(Categoria categoria) async {
    await _db.insertarCategoria(categoria);
    await cargarCategorias();
  }
 
  // ─── Actualizar ──────────────────────────────────────────────────────────────
 
  Future<void> actualizarCategoria(Categoria categoria) async {
    await _db.actualizarCategoria(categoria);
    await cargarCategorias();
  }
 
  // ─── Eliminar ────────────────────────────────────────────────────────────────
 
  Future<void> eliminarCategoria(int id) async {
    await _db.eliminarCategoria(id);
    await cargarCategorias();
  }
}