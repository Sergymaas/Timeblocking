class Plantilla {
  final int? id;
  final String nombre;
  final int numeroDias;

  const Plantilla({
    this.id,
    required this.nombre,
    required this.numeroDias,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'numero_dias': numeroDias,
    };
  }

  factory Plantilla.fromMap(Map<String, dynamic> map) {
    return Plantilla(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      numeroDias: map['numero_dias'] as int,
    );
  }
}