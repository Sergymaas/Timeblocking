import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plantilla.dart';
import '../models/dia_plantilla.dart';
import '../models/bloque_plantilla.dart';
import '../providers/plantilla_provider.dart';
import '../providers/categoria_provider.dart';
import '../models/categoria.dart';
import '../utils/fecha_utils.dart';
import 'formulario_bloque_plantilla.dart';

class PantallaDiasPlantilla extends StatefulWidget {
  final Plantilla plantilla;

  const PantallaDiasPlantilla({super.key, required this.plantilla});

  @override
  State<PantallaDiasPlantilla> createState() => _PantallaDiasPlantillaState();
}

class _PantallaDiasPlantillaState extends State<PantallaDiasPlantilla> {
  int _diaActual = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantillaProvider>().cargarDias(widget.plantilla.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantillaProvider>();
    final dias = provider.diasActuales;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plantilla.nombre),
      ),
      body: dias.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Selector de días ────────────────────────────────────
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: dias.length,
                    itemBuilder: (context, i) {
                      final seleccionado = i == _diaActual;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _diaActual = i);
                            provider.cargarBloques(dias[i].id!);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: seleccionado
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Día ${dias[i].numeroDia}',
                              style: TextStyle(
                                color: seleccionado
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: seleccionado
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: _VistaBloquesDia(
                    dia: dias.isNotEmpty ? dias[_diaActual] : null,
                    diasPlantilla: dias,
                  ),
                ),
              ],
            ),
      floatingActionButton: dias.isNotEmpty
          ? FloatingActionButton(
              heroTag: 'fab_plantilla',
              onPressed: () {
                final dia = dias[_diaActual];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormularioBloquePlantilla(
                      diaPlantillaId: dia.id!,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ─── Segmento de plantilla ────────────────────────────────────────────────────

class _SegmentoPlantilla {
  final int inicioMinutos;
  final int finMinutos;
  final BloquePlantilla? bloque;

  bool get esLibre => bloque == null;

  const _SegmentoPlantilla._({
    required this.inicioMinutos,
    required this.finMinutos,
    this.bloque,
  });

  factory _SegmentoPlantilla.libre(int inicio, int fin) =>
      _SegmentoPlantilla._(inicioMinutos: inicio, finMinutos: fin);

  factory _SegmentoPlantilla.bloque(int inicio, int fin, BloquePlantilla bloque) =>
      _SegmentoPlantilla._(inicioMinutos: inicio, finMinutos: fin, bloque: bloque);
}

// ─── Vista de bloques del día ─────────────────────────────────────────────────

class _VistaBloquesDia extends StatefulWidget {
  final DiaPlantilla? dia;
  final List<DiaPlantilla> diasPlantilla;

  const _VistaBloquesDia({this.dia, required this.diasPlantilla});

  @override
  State<_VistaBloquesDia> createState() => _VistaBloquesDiaState();
}

class _VistaBloquesDiaState extends State<_VistaBloquesDia> {
  static const int _inicioMinutos = 0;   // 00:00
  static const int _finMinutos = 1440;   // 24:00

  final Set<int> _bloquesSeleccionados = {};
  bool get _modoSeleccion => _bloquesSeleccionados.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.dia != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PlantillaProvider>().cargarBloques(widget.dia!.id!);
      });
    }
  }

  @override
  void didUpdateWidget(_VistaBloquesDia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dia?.id != oldWidget.dia?.id && widget.dia != null) {
      context.read<PlantillaProvider>().cargarBloques(widget.dia!.id!);
      setState(() => _bloquesSeleccionados.clear());
    }
  }

  List<_SegmentoPlantilla> _calcularSegmentos(List<BloquePlantilla> bloques) {
    final ordenados = [...bloques]
      ..sort((a, b) => a.horaInicioMinutos.compareTo(b.horaInicioMinutos));

    final segmentos = <_SegmentoPlantilla>[];
    int cursor = _inicioMinutos;

    for (final bloque in ordenados) {
      if (bloque.horaInicioMinutos > cursor) {
        final duracion = bloque.horaInicioMinutos - cursor;
        if (duracion > 1) {
          segmentos.add(_SegmentoPlantilla.libre(cursor, bloque.horaInicioMinutos));
        }
      }
      segmentos.add(_SegmentoPlantilla.bloque(
          bloque.horaInicioMinutos, bloque.horaFinMinutos, bloque));
      cursor = bloque.horaFinMinutos;
    }

    if (cursor < _finMinutos) {
      final duracion = _finMinutos - cursor;
      if (duracion > 1) {
        segmentos.add(_SegmentoPlantilla.libre(cursor, _finMinutos));
      }
    }

    return segmentos;
  }

  String _formatearMinutos(int minutos) {
    final h = (minutos ~/ 60).toString().padLeft(2, '0');
    final m = (minutos % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _copiarSeleccionadosAOtrosDias() async {
    final provider = context.read<PlantillaProvider>();
    final bloques = provider.bloquesActuales
        .where((b) => _bloquesSeleccionados.contains(b.id))
        .toList();

    final diasSeleccionados =
        List<bool>.filled(widget.diasPlantilla.length, false);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Copiar a otros días'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.diasPlantilla.length,
              itemBuilder: (context, i) {
                final dia = widget.diasPlantilla[i];
                if (dia.id == widget.dia?.id) return const SizedBox();
                return CheckboxListTile(
                  title: Text('Día ${dia.numeroDia}'),
                  value: diasSeleccionados[i],
                  onChanged: (v) =>
                      setStateDialog(() => diasSeleccionados[i] = v ?? false),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                for (int i = 0; i < widget.diasPlantilla.length; i++) {
                  if (!diasSeleccionados[i]) continue;
                  final dia = widget.diasPlantilla[i];
                  if (dia.id == widget.dia?.id) continue;
                  for (final bloque in bloques) {
                    await provider.insertarBloquePlantilla(BloquePlantilla(
                      diaPlantillaId: dia.id!,
                      titulo: bloque.titulo,
                      horaInicioMinutos: bloque.horaInicioMinutos,
                      horaFinMinutos: bloque.horaFinMinutos,
                      categoriaId: bloque.categoriaId,
                      notas: bloque.notas,
                    ));
                  }
                }
                setState(() => _bloquesSeleccionados.clear());
              },
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloques = context.watch<PlantillaProvider>().bloquesActuales;
    final categorias = context.watch<CategoriaProvider>().categorias;
    final segmentos = _calcularSegmentos(bloques);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 8, 16, 100),
        child: Column(
          children: [
            ...segmentos.map((seg) {
              if (seg.esLibre) {
                return _construirFila(
                  hora: _formatearMinutos(seg.inicioMinutos),
                  altura: 32,
                  child: _bloqueLibre(seg),
                );
              } else {
                final categoria =
                    _buscarCategoria(categorias, seg.bloque!.categoriaId);
                return _construirFila(
                  hora: _formatearMinutos(seg.inicioMinutos),
                  child: _bloqueActividad(seg, categoria),
                );
              }
            }).toList(),
            // Hora final
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '24:00',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomSheet: _modoSeleccion
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_bloquesSeleccionados.length} bloque${_bloquesSeleccionados.length > 1 ? 's' : ''} seleccionado${_bloquesSeleccionados.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _copiarSeleccionadosAOtrosDias,
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('Copiar'),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _bloquesSeleccionados.clear()),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _construirFila({
    required String hora,
    String? horaFin,
    double altura = 56,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: altura,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hora,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              if (horaFin != null)
                Text(
                  horaFin,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _bloqueLibre(_SegmentoPlantilla seg) {
    return GestureDetector(
      onTap: () {
        if (_modoSeleccion) {
          setState(() => _bloquesSeleccionados.clear());
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FormularioBloquePlantilla(
              diaPlantillaId: widget.dia!.id!,
              horaInicialMinutos: seg.inicioMinutos,
              horaFinalMinutos: seg.finMinutos,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 32,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 2,
            ),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _bloqueActividad(_SegmentoPlantilla seg, Categoria? categoria) {
    final color = categoria?.color ?? Colors.indigo;
    final seleccionado = _bloquesSeleccionados.contains(seg.bloque!.id);

    final duracionMin = seg.finMinutos - seg.inicioMinutos;
    final h = duracionMin ~/ 60;
    final m = duracionMin % 60;
    final duracionTexto = h == 0
        ? '${m}min'
        : m == 0
            ? '${h}h'
            : '${h}h ${m}min';

    return GestureDetector(
      onTap: () {
        if (_modoSeleccion) {
          setState(() {
            final id = seg.bloque!.id!;
            if (_bloquesSeleccionados.contains(id)) {
              _bloquesSeleccionados.remove(id);
            } else {
              _bloquesSeleccionados.add(id);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FormularioBloquePlantilla(
                diaPlantillaId: seg.bloque!.diaPlantillaId,
                bloque: seg.bloque,
              ),
            ),
          );
        }
      },
      onLongPress: () {
        setState(() => _bloquesSeleccionados.add(seg.bloque!.id!));
      },
      child: Container(
        width: double.infinity,
        height: 64,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: seleccionado
              ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6)
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          border: Border(
            left: BorderSide(color: color, width: 2),
            top: seleccionado ? BorderSide(color: color, width: 1) : BorderSide.none,
            right: seleccionado ? BorderSide(color: color, width: 1) : BorderSide.none,
            bottom: seleccionado ? BorderSide(color: color, width: 1) : BorderSide.none,
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              seg.bloque!.titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (categoria != null)
              Text(
                categoria.nombre,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              duracionTexto,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Categoria? _buscarCategoria(List<Categoria> categorias, int id) {
    try {
      return categorias.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}