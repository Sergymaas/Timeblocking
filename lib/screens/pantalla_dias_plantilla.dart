import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plantilla.dart';
import '../models/dia_plantilla.dart';
import '../models/bloque_plantilla.dart';
import '../providers/plantilla_provider.dart';
import '../providers/categoria_provider.dart';
import '../models/categoria.dart';
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
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
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Día ${dias[i].numeroDia}',
                              style: TextStyle(
                                color: seleccionado
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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

                // ── Bloques del día seleccionado ─────────────────────────
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

// ─── Vista de bloques del día ─────────────────────────────────────────────────

class _VistaBloquesDia extends StatefulWidget {
  final DiaPlantilla? dia;
  final List<DiaPlantilla> diasPlantilla;

  const _VistaBloquesDia({this.dia, required this.diasPlantilla});

  @override
  State<_VistaBloquesDia> createState() => _VistaBloquesDiaState();
}

class _VistaBloquesDiaState extends State<_VistaBloquesDia> {
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

  Future<void> _copiarSeleccionadosAOtrosDias() async {
    final provider = context.read<PlantillaProvider>();
    final bloques = provider.bloquesActuales
        .where((b) => _bloquesSeleccionados.contains(b.id))
        .toList();

    final diasSeleccionados = List<bool>.filled(
        widget.diasPlantilla.length, false);

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
                  onChanged: (v) => setStateDialog(
                      () => diasSeleccionados[i] = v ?? false),
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

    if (bloques.isEmpty) {
      return const Center(
        child: Text('No hay bloques. Pulsa + para añadir uno.'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: bloques.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final bloque = bloques[i];
          final categoria = _buscarCategoria(categorias, bloque.categoriaId);
          final color = categoria?.color ?? Colors.indigo;
          final seleccionado = _bloquesSeleccionados.contains(bloque.id);

          return GestureDetector(
            onTap: () {
              if (_modoSeleccion) {
                setState(() {
                  if (seleccionado) {
                    _bloquesSeleccionados.remove(bloque.id);
                  } else {
                    _bloquesSeleccionados.add(bloque.id!);
                  }
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormularioBloquePlantilla(
                      diaPlantillaId: bloque.diaPlantillaId,
                      bloque: bloque,
                    ),
                  ),
                );
              }
            },
            onLongPress: () {
              setState(() => _bloquesSeleccionados.add(bloque.id!));
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: seleccionado
                    ? color.withOpacity(0.35)
                    : color.withOpacity(0.15),
                border: Border(
                  left: BorderSide(color: color, width: 4),
                  top: seleccionado
                      ? BorderSide(color: color, width: 2)
                      : BorderSide.none,
                  right: seleccionado
                      ? BorderSide(color: color, width: 2)
                      : BorderSide.none,
                  bottom: seleccionado
                      ? BorderSide(color: color, width: 2)
                      : BorderSide.none,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bloque.titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color.withOpacity(0.9),
                      ),
                    ),
                  ),
                  Text(
                    '${bloque.horaInicioTexto} — ${bloque.horaFinTexto}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomSheet: _modoSeleccion
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Categoria? _buscarCategoria(List<Categoria> categorias, int id) {
    try {
      return categorias.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}