import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bloque_provider.dart';
import '../providers/categoria_provider.dart';
import '../models/bloque.dart';
import '../models/categoria.dart';
import 'formulario_bloque.dart';
import 'package:timeblocking/providers/calendario_provider.dart';
import 'package:timeblocking/services/calendario_service.dart';
import '../utils/fecha_utils.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  static const int _paginaCentral = 10000;
  late final PageController _pageController;
  late DateTime _diaActual;

  @override
  void initState() {
    super.initState();
    _diaActual = _soloFecha(DateTime.now());
    _pageController = PageController(initialPage: _paginaCentral);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoriaProvider>().cargarCategorias();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _diaDesde(int pagina) {
    final diferencia = pagina - _paginaCentral;
    return _soloFecha(DateTime.now()).add(Duration(days: diferencia));
  }

  Future<void> _abrirCalendario() async {
    final seleccionado = await showDatePicker(
      context: context,
      initialDate: _diaActual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (seleccionado == null) return;

    final diferencia = _soloFecha(seleccionado)
        .difference(_soloFecha(DateTime.now()))
        .inDays;
    final pagina = _paginaCentral + diferencia;

    _pageController.jumpToPage(pagina);
    setState(() => _diaActual = _soloFecha(seleccionado));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CategoriaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            ),
            GestureDetector(
              onTap: _abrirCalendario,
              child: Text(FechaUtils.formatearFecha(_diaActual)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              _pageController.jumpToPage(_paginaCentral);
              setState(() => _diaActual = _soloFecha(DateTime.now()));
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (pagina) {
          setState(() => _diaActual = _diaDesde(pagina));
        },
        itemCount: _paginaCentral + 30,
        itemBuilder: (context, pagina) {
          final dia = _diaDesde(pagina);
          return _VistaDia(dia: dia);
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_principal',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FormularioBloque(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Vista de un día ──────────────────────────────────────────────────────────

class _VistaDia extends StatefulWidget {
  final DateTime dia;
  const _VistaDia({required this.dia});

  @override
  State<_VistaDia> createState() => _VistaDiaState();
}

class _VistaDiaState extends State<_VistaDia> {
  static const double _alturaMinutoPx = 1.2;
  static const int _horaInicio = 0;
  static const int _horaFin = 24;
  static const double _alturaMinLibre = 32.0;

  final Set<int> _bloquesSeleccionados = {};
  bool get _modoSeleccion => _bloquesSeleccionados.isNotEmpty;

  List<_Segmento>? _segmentosCache;
  List<Bloque>? _bloquesAnterior;
  List<EventoCalendario>? _eventosAnterior;
  List<Bloque> _bloquesLocales = [];
  bool _cargando = true;
  int _versionCargada = -1;

  @override
void initState() {
  super.initState();
  _cargarBloquesLocales();
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final version = context.read<BloqueProvider>().version;
  if (version != _versionCargada) {
    _versionCargada = version;
    _cargarBloquesLocales();
  }
}

Future<void> _cargarBloquesLocales() async {
  final bloques = await DatabaseHelper.instance.obtenerBloquesPorDia(widget.dia);
  if (mounted) {
    setState(() {
      _bloquesLocales = bloques;
      _cargando = false;
    });
  }
}

  @override
    void didUpdateWidget(_VistaDia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dia != widget.dia) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BloqueProvider>().cargarBloques(widget.dia);
        context.read<CalendarioProvider>().cargarEventos(widget.dia);
      });
    }
  }

  DateTime _dt(int hora, int minuto) => DateTime(
        widget.dia.year,
        widget.dia.month,
        widget.dia.day,
        hora,
        minuto,
      );

  double _alturaParaMinutos(int minutos) => minutos * _alturaMinutoPx;

  List<_Segmento> _calcularSegmentos(
      List<Bloque> bloques, List<EventoCalendario> eventos) {
    final inicio = _dt(_horaInicio, 0);
    final fin = _dt(_horaFin, 0);

    final items = <_Segmento>[];

    for (final bloque in bloques) {
      final bloqueInicio = bloque.horaInicio.isBefore(inicio)
          ? inicio
          : bloque.horaInicio;
      final bloqueFin =
          bloque.horaFin.isAfter(fin) ? fin : bloque.horaFin;
      if (bloqueFin.isAfter(inicio) && bloqueInicio.isBefore(fin)) {
        items.add(_Segmento.bloque(bloqueInicio, bloqueFin, bloque));
      }
    }

    for (final evento in eventos) {
      final eventoInicio =
          evento.inicio.isBefore(inicio) ? inicio : evento.inicio;
      final eventoFin = evento.fin.isAfter(fin) ? fin : evento.fin;
      if (eventoFin.isAfter(inicio) && eventoInicio.isBefore(fin)) {
        items.add(_Segmento.evento(eventoInicio, eventoFin, evento));
      }
    }

    items.sort((a, b) => a.inicio.compareTo(b.inicio));

    final segmentos = <_Segmento>[];
    DateTime cursor = inicio;

    for (final item in items) {
      if (item.inicio.isAfter(cursor)) {
        segmentos.add(_Segmento.libre(cursor, item.inicio));
      }
      segmentos.add(item);
      cursor = item.fin;
    }

    if (cursor.isBefore(fin)) {
      segmentos.add(_Segmento.libre(cursor, fin));
    }

    return segmentos;
  }

  // ─── Mover bloques seleccionados ─────────────────────────────────────────────

  Future<void> _moverBloques(int minutos) async {
    final provider = context.read<BloqueProvider>();
    for (final id in _bloquesSeleccionados) {
      final bloque = provider.bloques.firstWhere((b) => b.id == id);
      final nuevaInicio = bloque.horaInicio.add(Duration(minutes: minutos));
      await provider.moverBloque(bloque, nuevaInicio);
    }
    setState(() => _bloquesSeleccionados.clear());
  }

  Future<void> _moverManual() async {
    final controller = TextEditingController();
    int? minutos;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mover bloques'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Introduce los minutos (negativo para adelantar):'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(suffixText: 'min'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              minutos = int.tryParse(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (minutos != null) await _moverBloques(minutos!);
  }

  Future<void> _eliminarBloques() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar bloques'),
        content: Text('¿Seguro que quieres eliminar ${_bloquesSeleccionados.length} bloque${_bloquesSeleccionados.length > 1 ? 's' : ''}?'),
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

    if (confirmar != true) return;

    final provider = context.read<BloqueProvider>();
    for (final id in _bloquesSeleccionados.toList()) {
      await provider.eliminarBloque(id);
    }
    setState(() => _bloquesSeleccionados.clear());
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<BloqueProvider>();
    final bloques = _bloquesLocales;
    final eventos = context.watch<CalendarioProvider>().eventosDelDia;
    final categorias = context.watch<CategoriaProvider>().categorias;
    if (_bloquesAnterior != bloques || _eventosAnterior != eventos) {
      _segmentosCache = _calcularSegmentos(bloques, eventos);
      _bloquesAnterior = bloques;
      _eventosAnterior = eventos;
    }
    final segmentos = _segmentosCache!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 8, 16, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...segmentos.map((seg) {
              if (seg.esLibre) {
                return _construirFila(
                  hora: FechaUtils.formatearHora(seg.inicio),
                  altura: 32.0,
                  child: _bloqueLibre(seg),
                );
              } else if (seg.esEvento) {
                return _construirFila(
                  hora: FechaUtils.formatearHora(seg.inicio),
                  altura: 48.0,
                  child: _bloqueEvento(seg),
                );
              } else {
                final categoria =
                    _buscarCategoria(categorias, seg.bloque!.categoriaId);
                return _construirFila(
                  hora: FechaUtils.formatearHora(seg.inicio),
                  altura: 48.0,
                  child: _bloqueActividad(seg, categoria),
                );
              }
            }).toList(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '24:00',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // Barra de selección
      bottomSheet: _modoSeleccion
          ? _BarraSeleccion(
              cantidad: _bloquesSeleccionados.length,
              onMover: _moverBloques,
              onManual: _moverManual,
              onCancelar: () =>
                  setState(() => _bloquesSeleccionados.clear()),
              onEliminar: _eliminarBloques,
            )
          : null,
    );
  }

  // ─── Fila con hora ────────────────────────────────────────────────────────────

  Widget _construirFila({
    required String hora,
    required double altura,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: altura,
          child: Text(
            hora,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  // ─── Bloque libre ─────────────────────────────────────────────────────────────

  Widget _bloqueLibre(_Segmento seg) {
    return GestureDetector(
      onTap: () {
        if (_modoSeleccion) {
          setState(() => _bloquesSeleccionados.clear());
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FormularioBloque(horaInicial: seg.inicio),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 32,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant
              .withOpacity(0.4),
          border: Border(
            left: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withOpacity(0.3),
              width: 4,
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

  // ─── Bloque de actividad ──────────────────────────────────────────────────────

  Widget _bloqueActividad(_Segmento seg, Categoria? categoria) {
    final minutos = seg.fin.difference(seg.inicio).inMinutes;
    final altura = 48.0;
    final color = categoria?.color ?? Colors.indigo;
    final paddingVertical = (altura * 0.08).clamp(2.0, 8.0);
    final seleccionado = _bloquesSeleccionados.contains(seg.bloque!.id);
    final completado = seg.bloque!.completado;

    final h = minutos ~/ 60;
    final m = minutos % 60;
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
          if (seg.bloque!.esOcurrencia) {
            _mostrarOpcionesOcurrencia(seg.bloque!);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FormularioBloque(bloque: seg.bloque),
              ),
            );
          }
        }
      },
      onLongPress: () {
        setState(() => _bloquesSeleccionados.add(seg.bloque!.id!));
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: completado
              ? color.withOpacity(0.06)
              : seleccionado
                  ? color.withOpacity(0.35)
                  : color.withOpacity(0.15),
          border: Border(
            left: BorderSide(
              color: completado ? color.withOpacity(0.3) : color,
              width: 4,
            ),
            top: seleccionado ? BorderSide(color: color, width: 2) : BorderSide.none,
            right: seleccionado ? BorderSide(color: color, width: 2) : BorderSide.none,
            bottom: seleccionado ? BorderSide(color: color, width: 2) : BorderSide.none,
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: paddingVertical),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seg.bloque!.titulo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: completado
                          ? color.withOpacity(0.4)
                          : color.withOpacity(0.9),
                      decoration: completado
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (altura > 38)
                    Text(
                      duracionTexto,
                      style: TextStyle(
                        fontSize: 11,
                        color: completado
                            ? color.withOpacity(0.3)
                            : color.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            // Botón completar/descompletar
            if (!_modoSeleccion && !seg.bloque!.horaInicio.isAfter(DateTime.now()))
              GestureDetector(
                onTap: () async {
                  if (completado) {
                    context.read<BloqueProvider>().descompletarBloque(seg.bloque!);
                  } else {
                    final ahora = DateTime.now();
                    final horaFin = seg.bloque!.horaFin;
                    
                    // Si la hora actual está dentro del rango del bloque, completa directamente
                    if (ahora.isAfter(seg.bloque!.horaInicio) && ahora.isBefore(horaFin)) {
                      context.read<BloqueProvider>().completarBloque(seg.bloque!, ahora);
                    } else {
                      // Ofrece elegir entre hora actual u hora de fin original
                      final opcion = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Completar bloque'),
                          content: const Text('¿Cuándo terminó este bloque?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Hora original (${FechaUtils.formatearHora(horaFin)})'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Ahora (${FechaUtils.formatearHora(ahora)})'),
                            ),
                          ],
                        ),
                      );
                      if (opcion == null) return;
                      final horaCompletado = opcion ? ahora : horaFin;
                      context.read<BloqueProvider>().completarBloque(seg.bloque!, horaCompletado);
                    }
                  }
                },
                child: Icon(
                  completado
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: completado
                      ? color.withOpacity(0.4)
                      : color.withOpacity(0.6),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Bloque de evento del calendario ─────────────────────────────────────────

  Widget _bloqueEvento(_Segmento seg) {
    final minutos = seg.fin.difference(seg.inicio).inMinutes;
    final altura = 48.0;
    final color = seg.evento!.color;
    final paddingVertical = (altura * 0.08).clamp(2.0, 8.0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: paddingVertical),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month,
                  size: 11, color: color.withOpacity(0.7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  seg.evento!.titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.9),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (altura > 38)
            Text(
              '${FechaUtils.formatearHora(seg.inicio)} — ${FechaUtils.formatearHora(seg.fin)}',
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Opciones de ocurrencia ───────────────────────────────────────────────────

  void _mostrarOpcionesOcurrencia(Bloque bloque) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar repetición'),
        content: const Text('¿Qué quieres editar?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final bloqueIndividual = Bloque.desdeInicioYFin(
                id: null,
                titulo: bloque.titulo,
                horaInicio: bloque.horaInicio,
                horaFin: bloque.horaFin,
                categoriaId: bloque.categoriaId,
                subcategoriaId: bloque.subcategoriaId,
                notas: bloque.notas,
                notificacionInicio: bloque.notificacionInicio,
                minutosAntes: bloque.minutosAntes,
                bloqueOriginalId: bloque.id,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FormularioBloque(bloque: bloqueIndividual),
                ),
              );
            },
            child: const Text('Solo esta'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FormularioBloque(bloque: bloque),
                ),
              );
            },
            child: const Text('Todas'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Categoria? _buscarCategoria(List<Categoria> categorias, int id) {
    try {
      return categorias.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ─── Barra de selección ───────────────────────────────────────────────────────

class _BarraSeleccion extends StatelessWidget {
  final int cantidad;
  final Future<void> Function(int minutos) onMover;
  final Future<void> Function() onManual;
  final VoidCallback onCancelar;
  final Future<void> Function() onEliminar;

  const _BarraSeleccion({
    required this.cantidad,
    required this.onMover,
    required this.onManual,
    required this.onCancelar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$cantidad bloque${cantidad > 1 ? 's' : ''} seleccionado${cantidad > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: onEliminar,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Eliminar'),
                  ),
                  TextButton(
                    onPressed: onCancelar,
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _botonMover(context, '-1h', -60),
                _botonMover(context, '-30m', -30),
                _botonMover(context, '-15m', -15),
                _botonMover(context, '+15m', 15),
                _botonMover(context, '+30m', 30),
                _botonMover(context, '+1h', 60),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Manual'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonMover(BuildContext context, String label, int minutos) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ElevatedButton(
        onPressed: () => onMover(minutos),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
        ),
        child: Text(label),
      ),
    );
  }
}

// ─── Modelo de segmento ───────────────────────────────────────────────────────

class _Segmento {
  final DateTime inicio;
  final DateTime fin;
  final Bloque? bloque;
  final EventoCalendario? evento;

  bool get esLibre => bloque == null && evento == null;
  bool get esEvento => evento != null;

  const _Segmento._({
    required this.inicio,
    required this.fin,
    this.bloque,
    this.evento,
  });

  factory _Segmento.libre(DateTime inicio, DateTime fin) =>
      _Segmento._(inicio: inicio, fin: fin);

  factory _Segmento.bloque(DateTime inicio, DateTime fin, Bloque bloque) =>
      _Segmento._(inicio: inicio, fin: fin, bloque: bloque);

  factory _Segmento.evento(
          DateTime inicio, DateTime fin, EventoCalendario evento) =>
      _Segmento._(inicio: inicio, fin: fin, evento: evento);
}