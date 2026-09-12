class BloquePlantilla {
  final int? id;
  final int diaPlantillaId;
  final String titulo;
  final int horaInicioMinutos; // minutos desde medianoche (ej. 9:30 = 570)
  final int horaFinMinutos;
  final int categoriaId;
  final int? subcategoriaId;
  final String? notas;

  const BloquePlantilla({
    this.id,
    required this.diaPlantillaId,
    required this.titulo,
    required this.horaInicioMinutos,
    required this.horaFinMinutos,
    required this.categoriaId,
    this.subcategoriaId,
    this.notas,
  });

  // Duración calculada
  int get duracionMinutos => horaFinMinutos - horaInicioMinutos;

  // Hora de inicio formateada
  String get horaInicioTexto {
    final h = (horaInicioMinutos ~/ 60).toString().padLeft(2, '0');
    final m = (horaInicioMinutos % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Hora de fin formateada
  String get horaFinTexto {
    final h = (horaFinMinutos ~/ 60).toString().padLeft(2, '0');
    final m = (horaFinMinutos % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dia_plantilla_id': diaPlantillaId,
      'titulo': titulo,
      'hora_inicio_minutos': horaInicioMinutos,
      'hora_fin_minutos': horaFinMinutos,
      'categoria_id': categoriaId,
      'subcategoria_id': subcategoriaId,
      'notas': notas,
    };
  }

  factory BloquePlantilla.fromMap(Map<String, dynamic> map) {
    return BloquePlantilla(
      id: map['id'] as int?,
      diaPlantillaId: map['dia_plantilla_id'] as int,
      titulo: map['titulo'] as String,
      horaInicioMinutos: map['hora_inicio_minutos'] as int,
      horaFinMinutos: map['hora_fin_minutos'] as int,
      categoriaId: map['categoria_id'] as int,
      subcategoriaId: map['subcategoria_id'] as int?,
      notas: map['notas'] as String?,
    );
  }
}