import 'package:flutter/material.dart';


// ─── Categoría ───────────────────────────────────────────────────────────────
 
class Categoria {
  final int? id;
  final String nombre;
  final Color color;
 
  const Categoria({
    this.id,
    required this.nombre,
    required this.color,
  });
 
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'color': color.value,
    };
  }
 
  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      color: Color(map['color'] as int),
    );
  }
}