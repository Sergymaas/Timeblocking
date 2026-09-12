class DiaPlantilla {
  final int? id;
  final int plantillaId;
  final int numeroDia; // 1 a 14

  const DiaPlantilla({
    this.id,
    required this.plantillaId,
    required this.numeroDia,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plantilla_id': plantillaId,
      'numero_dia': numeroDia,
    };
  }

  factory DiaPlantilla.fromMap(Map<String, dynamic> map) {
    return DiaPlantilla(
      id: map['id'] as int?,
      plantillaId: map['plantilla_id'] as int,
      numeroDia: map['numero_dia'] as int,
    );
  }
}