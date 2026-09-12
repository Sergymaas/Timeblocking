import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bloque_plantilla.dart';
import '../models/categoria.dart';
import '../providers/categoria_provider.dart';
import '../providers/plantilla_provider.dart';
import '../models/dia_plantilla.dart';

class FormularioBloquePlantilla extends StatefulWidget {
  final int diaPlantillaId;
  final BloquePlantilla? bloque;

  const FormularioBloquePlantilla({
    super.key,
    required this.diaPlantillaId,
    this.bloque,
  });

  @override
  State<FormularioBloquePlantilla> createState() =>
      _FormularioBloquePlantillaState();
}

class _FormularioBloquePlantillaState
    extends State<FormularioBloquePlantilla> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _notasController;

  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  int _modoEntrada = 1;
  int? _duracionMinutos;

  Categoria? _categoriaSeleccionada;

  @override
  void initState() {
    super.initState();
    final b = widget.bloque;
    _tituloController = TextEditingController(text: b?.titulo ?? '');
    _notasController = TextEditingController(text: b?.notas ?? '');

    if (b != null) {
      _horaInicio = TimeOfDay(
        hour: b.horaInicioMinutos ~/ 60,
        minute: b.horaInicioMinutos % 60,
      );
      _horaFin = TimeOfDay(
        hour: b.horaFinMinutos ~/ 60,
        minute: b.horaFinMinutos % 60,
      );
      _duracionMinutos = b.duracionMinutos;
      _modoEntrada = 0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CategoriaProvider>().cargarCategorias();
      if (b != null) {
        final categorias = context.read<CategoriaProvider>().categorias;
        try {
          _categoriaSeleccionada =
              categorias.firstWhere((c) => c.id == b.categoriaId);
        } catch (_) {}
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  String _formatearHora(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _formatearDuracion(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  Future<void> _seleccionarHora(bool esInicio) async {
    final inicial = esInicio
        ? (_horaInicio ?? TimeOfDay.now())
        : (_horaFin ?? TimeOfDay.now());

    final seleccionada = await showTimePicker(
      context: context,
      initialTime: inicial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (seleccionada == null) return;

    setState(() {
      if (esInicio) {
        _horaInicio = seleccionada;
        if (_modoEntrada == 1 && _duracionMinutos != null) {
          final inicioMin = seleccionada.hour * 60 + seleccionada.minute;
          final finMin = inicioMin + _duracionMinutos!;
          _horaFin = TimeOfDay(hour: finMin ~/ 60, minute: finMin % 60);
        } else if (_modoEntrada == 0 && _horaFin != null) {
          final inicioMin = seleccionada.hour * 60 + seleccionada.minute;
          final finMin = _horaFin!.hour * 60 + _horaFin!.minute;
          _duracionMinutos = (finMin - inicioMin).clamp(0, 1440);
        }
      } else {
        _horaFin = seleccionada;
        if (_modoEntrada == 2 && _duracionMinutos != null) {
          final finMin = seleccionada.hour * 60 + seleccionada.minute;
          final inicioMin = finMin - _duracionMinutos!;
          _horaInicio =
              TimeOfDay(hour: inicioMin ~/ 60, minute: inicioMin % 60);
        } else if (_modoEntrada == 0 && _horaInicio != null) {
          final inicioMin = _horaInicio!.hour * 60 + _horaInicio!.minute;
          final finMin = seleccionada.hour * 60 + seleccionada.minute;
          _duracionMinutos = (finMin - inicioMin).clamp(0, 1440);
        }
      }
    });
  }

  Future<void> _seleccionarDuracion() async {
    final controller = TextEditingController(
      text: _duracionMinutos?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duración en minutos'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'min'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final minutos = int.tryParse(controller.text);
              if (minutos != null && minutos > 0) {
                setState(() {
                  _duracionMinutos = minutos;
                  if (_modoEntrada == 1 && _horaInicio != null) {
                    final inicioMin =
                        _horaInicio!.hour * 60 + _horaInicio!.minute;
                    final finMin = inicioMin + minutos;
                    _horaFin =
                        TimeOfDay(hour: finMin ~/ 60, minute: finMin % 60);
                  } else if (_modoEntrada == 2 && _horaFin != null) {
                    final finMin = _horaFin!.hour * 60 + _horaFin!.minute;
                    final inicioMin = finMin - minutos;
                    _horaInicio = TimeOfDay(
                        hour: inicioMin ~/ 60, minute: inicioMin % 60);
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarAOtrosDias(int bloqueId) async {
    final provider = context.read<PlantillaProvider>();
    final dias = provider.diasActuales;
    final diasSeleccionados = List<bool>.filled(dias.length, false);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Copiar a otros días'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dias.length,
              itemBuilder: (context, i) {
                if (dias[i].id == widget.diaPlantillaId) return const SizedBox();
                return CheckboxListTile(
                  title: Text('Día ${dias[i].numeroDia}'),
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
                for (int i = 0; i < dias.length; i++) {
                  if (!diasSeleccionados[i]) continue;
                  if (dias[i].id == widget.diaPlantillaId) continue;
                  await provider.insertarBloquePlantilla(BloquePlantilla(
                    diaPlantillaId: dias[i].id!,
                    titulo: _tituloController.text.trim(),
                    horaInicioMinutos:
                        _horaInicio!.hour * 60 + _horaInicio!.minute,
                    horaFinMinutos: _horaFin!.hour * 60 + _horaFin!.minute,
                    categoriaId: _categoriaSeleccionada!.id!,
                    notas: _notasController.text.trim().isEmpty
                        ? null
                        : _notasController.text.trim(),
                  ));
                }
              },
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    if (_horaInicio == null || _horaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa las horas')),
      );
      return;
    }
    if (_categoriaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }

    final bloque = BloquePlantilla(
      id: widget.bloque?.id,
      diaPlantillaId: widget.diaPlantillaId,
      titulo: _tituloController.text.trim(),
      horaInicioMinutos: _horaInicio!.hour * 60 + _horaInicio!.minute,
      horaFinMinutos: _horaFin!.hour * 60 + _horaFin!.minute,
      categoriaId: _categoriaSeleccionada!.id!,
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
    );

    final provider = context.read<PlantillaProvider>();
    if (widget.bloque == null) {
      provider.insertarBloquePlantilla(bloque);
    } else {
      provider.actualizarBloquePlantilla(bloque);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<CategoriaProvider>().categorias;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bloque == null
            ? 'Nuevo bloque'
            : 'Editar bloque'),
        actions: [
          if (_horaInicio != null && _horaFin != null && _categoriaSeleccionada != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copiar a otros días',
              onPressed: () => _copiarAOtrosDias(widget.bloque?.id ?? 0),
            ),
          if (widget.bloque != null)
            TextButton(
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar bloque'),
                    content:
                        const Text('¿Seguro que quieres eliminar este bloque?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  context.read<PlantillaProvider>().eliminarBloquePlantilla(
                      widget.bloque!.id!, widget.diaPlantillaId);
                  Navigator.pop(context);
                }
              },
              child: const Text('Eliminar'),
            ),
          TextButton(
            onPressed: _guardar,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Título ────────────────────────────────────────────────────
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El título es obligatorio'
                  : null,
            ),

            const SizedBox(height: 16),

            // ── Notas ─────────────────────────────────────────────────────
            TextFormField(
              controller: _notasController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // ── Modo de entrada ───────────────────────────────────────────
            Text('Modo de entrada',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Inicio + Fin')),
                ButtonSegment(value: 1, label: Text('Inicio + Dur.')),
                ButtonSegment(value: 2, label: Text('Fin + Dur.')),
              ],
              selected: {_modoEntrada},
              onSelectionChanged: (s) =>
                  setState(() => _modoEntrada = s.first),
            ),

            const SizedBox(height: 16),

            if (_modoEntrada == 0 || _modoEntrada == 1)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora de inicio'),
                trailing: Text(
                  _horaInicio != null ? _formatearHora(_horaInicio!) : '--:--',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _seleccionarHora(true),
              ),

            if (_modoEntrada == 0 || _modoEntrada == 2)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora de fin'),
                trailing: Text(
                  _horaFin != null ? _formatearHora(_horaFin!) : '--:--',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _seleccionarHora(false),
              ),

            if (_modoEntrada == 1 || _modoEntrada == 2)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Duración'),
                trailing: Text(
                  _duracionMinutos != null
                      ? _formatearDuracion(_duracionMinutos!)
                      : '--',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: _seleccionarDuracion,
              ),

            const Divider(height: 32),

            // ── Categoría ─────────────────────────────────────────────────
            Text('Categoría',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<Categoria>(
              value: _categoriaSeleccionada,
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Selecciona una categoría'),
              items: categorias.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      CircleAvatar(
                          backgroundColor: c.color, radius: 8),
                      const SizedBox(width: 8),
                      Text(c.nombre),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (c) =>
                  setState(() => _categoriaSeleccionada = c),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}