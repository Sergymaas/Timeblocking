import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bloque.dart';
import '../models/categoria.dart';
import '../models/subcategoria.dart';
import '../models/repeticion.dart';
import '../providers/bloque_provider.dart';
import '../providers/categoria_provider.dart';
import '../providers/subcategoria_provider.dart';
import '../utils/fecha_utils.dart';

class FormularioBloque extends StatefulWidget {
  final Bloque? bloque;
  final DateTime? horaInicial;
  final DateTime? horaFinal;

  const FormularioBloque({super.key, this.bloque, this.horaInicial, this.horaFinal});

  @override
  State<FormularioBloque> createState() => _FormularioBloqueState();
}

class _FormularioBloqueState extends State<FormularioBloque> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _tituloController;
  late TextEditingController _notasController;
  late DateTime _diaSeleccionado;

  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  int? _duracionMinutos;
  int _modoEntrada = 1;

  Categoria? _categoriaSeleccionada;
  Subcategoria? _subcategoriaSeleccionada;

  bool _tieneRepeticion = false;
  Frecuencia _frecuencia = Frecuencia.semanal;
  final List<bool> _diasSeleccionados = List.filled(7, false);
  DateTime? _fechaLimiteRepeticion;

  bool _notificacionInicio = false;
  int? _minutosAntes;

  @override
  void initState() {
    super.initState();

    final b = widget.bloque;
    _tituloController = TextEditingController(text: b?.titulo ?? '');
    _notasController = TextEditingController(text: b?.notas ?? '');
    _diaSeleccionado = widget.bloque?.horaInicio != null
      ? FechaUtils.soloFecha(widget.bloque!.horaInicio)
      : (widget.horaInicial != null
        ? FechaUtils.soloFecha(widget.horaInicial!)
        : FechaUtils.soloFecha(DateTime.now()));
    _notificacionInicio = b?.notificacionInicio ?? false;
    _minutosAntes = b?.minutosAntes;
    _fechaLimiteRepeticion = b?.repeticion?.fechaLimite;

    if (b == null && widget.horaInicial != null) {
      _horaInicio = TimeOfDay.fromDateTime(widget.horaInicial!);
      _modoEntrada = 0;
    }

    if (b == null && widget.horaFinal !=null) {
      _horaFin = TimeOfDay.fromDateTime(widget.horaFinal!);
      if (_horaInicio != null) {
        final inicioMin = _horaInicio!.hour * 60 + _horaInicio!.minute;
        final finMin = _horaFin!.hour * 60 + _horaFin!.minute;
        _duracionMinutos = (finMin - inicioMin).clamp(0, 1440);
      }
    }

    if (b != null) {
      _horaInicio = TimeOfDay.fromDateTime(b.horaInicio);
      _horaFin = TimeOfDay.fromDateTime(b.horaFin);
      _duracionMinutos = b.duracion.inMinutes;
      _modoEntrada = 0;

      if (b.repeticion != null) {
        _tieneRepeticion = true;
        _frecuencia = b.repeticion!.frecuencia;
        for (final dia in b.repeticion!.dias) {
          _diasSeleccionados[dia] = true;
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CategoriaProvider>().cargarCategorias();
      context.read<SubcategoriaProvider>().cargarSubcategorias();

      if (b != null) {
        final categorias = context.read<CategoriaProvider>().categorias;
        try {
          _categoriaSeleccionada =
              categorias.firstWhere((c) => c.id == b.categoriaId);
          context
              .read<SubcategoriaProvider>()
              .cargarSubcategorias(categoriaId: b.categoriaId);

          if (b.subcategoriaId != null) {
            final subcategorias =
                context.read<SubcategoriaProvider>().subcategorias;
            try {
              _subcategoriaSeleccionada =
                  subcategorias.firstWhere((s) => s.id == b.subcategoriaId);
            } catch (_) {}
          }
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

  DateTime _toDateTime(TimeOfDay t) {
    return DateTime(
      _diaSeleccionado.year,
      _diaSeleccionado.month,
      _diaSeleccionado.day,
      t.hour,
      t.minute,
    );
  }

  String _formatearHora(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatearDuracion(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

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

  void _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar bloque'),
        content: const Text('¿Seguro que quieres eliminar este bloque?'),
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
      context.read<BloqueProvider>().eliminarBloque(widget.bloque!.id!);
      Navigator.pop(context);
    }
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    if (_horaInicio == null || _horaFin == null || _duracionMinutos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa las horas y la duración')),
      );
      return;
    }
    if (_categoriaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }

    Repeticion? repeticion;
    if (_tieneRepeticion) {
      final diasMarcados = <int>[];
      for (int i = 0; i < 7; i++) {
        if (_diasSeleccionados[i]) diasMarcados.add(i);
      }
      repeticion = Repeticion(
        frecuencia: _frecuencia,
        dias: diasMarcados,
        fechaLimite: _fechaLimiteRepeticion,
      );
    }

    final bloque = Bloque.desdeInicioYFin(
      id: widget.bloque?.id,
      titulo: _tituloController.text.trim(),
      horaInicio: _toDateTime(_horaInicio!),
      horaFin: _toDateTime(_horaFin!),
      categoriaId: _categoriaSeleccionada!.id!,
      subcategoriaId: _subcategoriaSeleccionada?.id,
      repeticion: repeticion,
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
      notificacionInicio: _notificacionInicio,
      minutosAntes: _minutosAntes,
      bloqueOriginalId: widget.bloque?.bloqueOriginalId,
      plantillaId: widget.bloque?.plantillaId,
    );

    // Si el bloque viene de una plantilla y es edición, ofrece opciones
    if (widget.bloque != null && widget.bloque!.plantillaId != null) {
      _mostrarOpcionesEdicionPlantilla(bloque);
    } else {
      _aplicarGuardado(bloque);
    }
  }

  void _mostrarOpcionesEdicionPlantilla(Bloque bloque) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar bloque de plantilla'),
        content: const Text('¿Qué quieres cambiar?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _aplicarGuardado(bloque);
            },
            child: const Text('Solo este día'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<BloqueProvider>()
                  .actualizarBloqueYSiguientes(bloque);
              Navigator.pop(context);
            },
            child: const Text('Este y los siguientes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _aplicarGuardado(Bloque bloque) {
    final provider = context.read<BloqueProvider>();
    if (bloque.id == null) {
      provider.insertarBloque(bloque);
    } else {
      provider.actualizarBloque(bloque);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<CategoriaProvider>().categorias;
    final subcategorias = context.watch<SubcategoriaProvider>().subcategorias;
    const diasNombres = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bloque == null ? 'Nuevo bloque' : 'Editar bloque'),
        actions: [
          if (widget.bloque != null)
            TextButton(
              onPressed: _eliminar,
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

            // ── Título ──────────────────────────────────────────────────────
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

            // ── Notas ───────────────────────────────────────────────────────
            TextFormField(
              controller: _notasController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Día'),
              trailing: Text(
                FechaUtils.formatearFecha(_diaSeleccionado),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () async {
                final seleccionado = await showDatePicker(
                  context: context,
                  initialDate: _diaSeleccionado,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (seleccionado != null) {
                  setState(() => _diaSeleccionado = seleccionado);
                }
              },
            ),

            const SizedBox(height: 24),

            // ── Modo de entrada ─────────────────────────────────────────────
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

            // ── Hora inicio ─────────────────────────────────────────────────
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

            // ── Hora fin ────────────────────────────────────────────────────
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

            // ── Duración ────────────────────────────────────────────────────
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

            // ── Categoría ───────────────────────────────────────────────────
            Text('Categoría',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<Categoria>(
              initialValue: _categoriaSeleccionada,
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
              onChanged: (c) {
                setState(() {
                  _categoriaSeleccionada = c;
                  _subcategoriaSeleccionada = null;
                });
                if (c?.id != null) {
                  context
                      .read<SubcategoriaProvider>()
                      .cargarSubcategorias(categoriaId: c!.id!);
                }
              },
            ),

            if (_categoriaSeleccionada != null &&
                subcategorias.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<Subcategoria>(
                initialValue: _subcategoriaSeleccionada,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Subcategoría (opcional)',
                ),
                items: subcategorias.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.nombre),
                  );
                }).toList(),
                onChanged: (s) =>
                    setState(() => _subcategoriaSeleccionada = s),
              ),
            ],

            const Divider(height: 32),

            // ── Repetición ──────────────────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repetición'),
              value: _tieneRepeticion,
              onChanged: (v) => setState(() => _tieneRepeticion = v),
            ),

            if (_tieneRepeticion) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<Frecuencia>(
                initialValue: _frecuencia,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Frecuencia',
                ),
                items: const [
                  DropdownMenuItem(
                      value: Frecuencia.diaria, child: Text('Diaria')),
                  DropdownMenuItem(
                      value: Frecuencia.semanal, child: Text('Semanal')),
                  DropdownMenuItem(
                      value: Frecuencia.bisemanal,
                      child: Text('Bisemanal')),
                  DropdownMenuItem(
                      value: Frecuencia.mensual, child: Text('Mensual')),
                ],
                onChanged: (f) => setState(
                    () => _frecuencia = f ?? Frecuencia.semanal),
              ),

              // ── Fecha límite ─────────────────────────────────────────────────────
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha límite (opcional)'),
                trailing: Text(
                  _fechaLimiteRepeticion != null
                      ? FechaUtils.formatearFecha(_fechaLimiteRepeticion!)
                      : 'Sin límite',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () async {
                  final seleccionada = await showDatePicker(
                    context: context,
                    initialDate: _fechaLimiteRepeticion ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  setState(() => _fechaLimiteRepeticion = seleccionada);
                },
              ),
              if (_fechaLimiteRepeticion != null)
                TextButton(
                  onPressed: () => setState(() => _fechaLimiteRepeticion = null),
                  child: const Text('Eliminar fecha límite'),
                ),
            ],

            const Divider(height: 32),

            // ── Notificaciones ──────────────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notificación al inicio'),
              value: _notificacionInicio,
              onChanged: (v) => setState(() => _notificacionInicio = v),
           ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aviso previo'),
              trailing: DropdownButton<int?>(
                value: _minutosAntes,
                hint: const Text('Ninguno'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Ninguno')),
                  DropdownMenuItem(value: 5, child: Text('5 min')),
                  DropdownMenuItem(value: 10, child: Text('10 min')),
                  DropdownMenuItem(value: 15, child: Text('15 min')),
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 60, child: Text('1 hora')),
                ],
                onChanged: (v) => setState(() => _minutosAntes = v),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}