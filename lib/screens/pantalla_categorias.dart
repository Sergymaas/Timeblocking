import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categoria.dart';
import '../providers/categoria_provider.dart';

class PantallaCategorias extends StatelessWidget {
  const PantallaCategorias({super.key});

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<CategoriaProvider>().categorias;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: categorias.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final categoria = categorias[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: categoria.color,
              radius: 14,
            ),
            title: Text(categoria.nombre),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrirFormulario(context, categoria: categoria),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _abrirFormulario(BuildContext context, {Categoria? categoria}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FormularioCategoria(categoria: categoria),
      ),
    );
  }
}

// ─── Formulario de categoría ──────────────────────────────────────────────────

class _FormularioCategoria extends StatefulWidget {
  final Categoria? categoria;

  const _FormularioCategoria({this.categoria});

  @override
  State<_FormularioCategoria> createState() => _FormularioCategoriaState();
}

class _FormularioCategoriaState extends State<_FormularioCategoria> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late Color _colorSeleccionado;

  // Paleta fija de 20 colores
  static const List<Color> _paleta = [
    Color(0xFF1565C0), // azul oscuro
    Color(0xFF1976D2), // azul
    Color(0xFF0288D1), // azul claro
    Color(0xFF0097A7), // cian
    Color(0xFF00796B), // teal
    Color(0xFF2E7D32), // verde oscuro
    Color(0xFF388E3C), // verde
    Color(0xFF689F38), // verde claro
    Color(0xFFF57F17), // amarillo oscuro
    Color(0xFFEF6C00), // naranja oscuro
    Color(0xFFE65100), // naranja
    Color(0xFFD84315), // naranja rojizo
    Color(0xFFC62828), // rojo oscuro
    Color(0xFFAD1457), // rosa oscuro
    Color(0xFF6A1B9A), // morado oscuro
    Color(0xFF4527A0), // violeta oscuro
    Color(0xFF283593), // índigo oscuro
    Color(0xFF4E342E), // marrón
    Color(0xFF37474F), // gris azulado
    Color(0xFF546E7A), // gris azulado claro
  ];

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.categoria?.nombre ?? '');
    _colorSeleccionado = widget.categoria?.color ?? _paleta.first;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CategoriaProvider>();
    final categoria = Categoria(
      id: widget.categoria?.id,
      nombre: _nombreController.text.trim(),
      color: _colorSeleccionado,
    );

    if (widget.categoria == null) {
      provider.insertarCategoria(categoria);
    } else {
      provider.actualizarCategoria(categoria);
    }

    Navigator.pop(context);
  }

  void _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: const Text(
            '¿Seguro que quieres eliminar esta categoría? Los bloques asociados perderán su categoría.'),
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
      context.read<CategoriaProvider>().eliminarCategoria(widget.categoria!.id!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.categoria == null ? 'Nueva categoría' : 'Editar categoría'),
        actions: [
          if (widget.categoria != null)
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
            // ── Nombre ────────────────────────────────────────────────────
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre es obligatorio'
                  : null,
            ),

            const SizedBox(height: 24),

            // ── Color ─────────────────────────────────────────────────────
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _paleta.map((color) {
                final seleccionado = _colorSeleccionado.value == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _colorSeleccionado = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: seleccionado
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                      boxShadow: seleccionado
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: seleccionado
                        ? Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Vista previa ──────────────────────────────────────────────
            Text('Vista previa', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: _colorSeleccionado.withOpacity(0.15),
                border: Border(
                  left: BorderSide(color: _colorSeleccionado, width: 4),
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _nombreController.text.isEmpty
                        ? 'Nombre de la actividad'
                        : _nombreController.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _colorSeleccionado.withOpacity(0.9),
                    ),
                  ),
                  Text(
                    '09:00 — 10:00',
                    style: TextStyle(
                      fontSize: 11,
                      color: _colorSeleccionado.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}