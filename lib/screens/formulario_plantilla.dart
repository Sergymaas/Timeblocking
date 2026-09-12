import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plantilla.dart';
import '../providers/plantilla_provider.dart';

class FormularioPlantilla extends StatefulWidget {
  final Plantilla? plantilla;

  const FormularioPlantilla({super.key, this.plantilla});

  @override
  State<FormularioPlantilla> createState() => _FormularioPlantillaState();
}

class _FormularioPlantillaState extends State<FormularioPlantilla> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  int _numeroDias = 1;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.plantilla?.nombre ?? '');
    _numeroDias = widget.plantilla?.numeroDias ?? 1;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<PlantillaProvider>();
    final plantilla = Plantilla(
      id: widget.plantilla?.id,
      nombre: _nombreController.text.trim(),
      numeroDias: _numeroDias,
    );

    if (widget.plantilla == null) {
      provider.insertarPlantilla(plantilla);
    } else {
      provider.actualizarPlantilla(plantilla);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plantilla == null
            ? 'Nueva plantilla'
            : 'Editar plantilla'),
        actions: [
          if (widget.plantilla != null)
            TextButton(
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar plantilla'),
                    content: const Text(
                        '¿Seguro que quieres eliminar esta plantilla y todos sus bloques?'),
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
                  context
                      .read<PlantillaProvider>()
                      .eliminarPlantilla(widget.plantilla!.id!);
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
            // ── Nombre ────────────────────────────────────────────────────
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la plantilla',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre es obligatorio'
                  : null,
            ),

            const SizedBox(height: 24),

            // ── Número de días ────────────────────────────────────────────
            Text('Número de días',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _numeroDias > 1
                      ? () => setState(() => _numeroDias--)
                      : null,
                ),
                Expanded(
                  child: Text(
                    '$_numeroDias ${_numeroDias == 1 ? 'día' : 'días'}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _numeroDias < 14
                      ? () => setState(() => _numeroDias++)
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Slider(
              value: _numeroDias.toDouble(),
              min: 1,
              max: 14,
              divisions: 13,
              label: '$_numeroDias',
              onChanged: (v) => setState(() => _numeroDias = v.round()),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}