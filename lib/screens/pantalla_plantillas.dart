import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plantilla.dart';
import '../providers/plantilla_provider.dart';
import '../providers/bloque_provider.dart';
import 'formulario_plantilla.dart';
import 'pantalla_dias_plantilla.dart';
import '../services/repeticion_plantilla_service.dart';
import '../utils/fecha_utils.dart';

class PantallaPlantillas extends StatefulWidget {
  const PantallaPlantillas({super.key});

  @override
  State<PantallaPlantillas> createState() => _PantallaPlantillasState();
}

class _PantallaPlantillasState extends State<PantallaPlantillas> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantillaProvider>().cargarPlantillas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final plantillas = context.watch<PlantillaProvider>().plantillas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas'),
      ),
      body: plantillas.isEmpty
          ? const Center(
              child: Text('No hay plantillas. Pulsa + para crear una.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plantillas.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final plantilla = plantillas[i];
                return ListTile(
                  title: Text(plantilla.nombre),
                  subtitle: Text(
                      '${plantilla.numeroDias} ${plantilla.numeroDias == 1 ? 'día' : 'días'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar plantilla',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FormularioPlantilla(plantilla: plantilla),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow_outlined),
                        tooltip: 'Aplicar plantilla',
                        onPressed: () => _mostrarDialogoAplicar(context, plantilla),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PantallaDiasPlantilla(plantilla: plantilla),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_plantillas',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FormularioPlantilla(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _mostrarDialogoAplicar(
      BuildContext context, Plantilla plantilla) async {
    DateTime fechaInicio = DateTime.now();
    String? frecuencia; // null = sin repetición, 'semanal', 'mensual'
    DateTime? fechaLimite;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Aplicar "${plantilla.nombre}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fecha de inicio:'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final seleccionada = await showDatePicker(
                    context: context,
                    initialDate: fechaInicio,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (seleccionada != null) {
                    setStateDialog(() => fechaInicio = seleccionada);
                  }
                },
                child: Text(FechaUtils.formatearFechaCorta(fechaInicio)),
              ),
              const SizedBox(height: 16),
              const Text('Repetición:'),
              const SizedBox(height: 8),
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Una vez')),
                  ButtonSegment(value: 'semanal', label: Text('Semanal')),
                  ButtonSegment(value: 'mensual', label: Text('Mensual')),
                ],
                selected: {frecuencia},
                onSelectionChanged: (s) =>
                    setStateDialog(() => frecuencia = s.first),
              ),
              if (frecuencia != null) ...[
                const SizedBox(height: 16),
                const Text('Fecha límite (opcional):'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final seleccionada = await showDatePicker(
                      context: context,
                      initialDate: fechaLimite ?? fechaInicio,
                      firstDate: fechaInicio,
                      lastDate: DateTime(2100),
                    );
                    if (seleccionada != null) {
                      setStateDialog(() => fechaLimite = seleccionada);
                    }
                  },
                  child: Text(fechaLimite != null
                      ? FechaUtils.formatearFecha(fechaLimite!)
                      : 'Sin límite'),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Se aplicará del ${FechaUtils.formatearFechaCorta(fechaInicio)} '
                'al ${FechaUtils.formatearFechaCorta(fechaInicio.add(Duration(days: plantilla.numeroDias - 1)))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _aplicarConVerificacion(
                    context, plantilla, fechaInicio, frecuencia, fechaLimite);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aplicarConVerificacion(
    BuildContext context,
    Plantilla plantilla,
    DateTime fechaInicio,
    String? frecuencia,
    DateTime? fechaLimite,
  ) async {
    final provider = context.read<PlantillaProvider>();
    final bloqueProvider = context.read<BloqueProvider>();
    
    final solapados =
        await provider.verificarSolapamientos(plantilla.id!, fechaInicio);

    if (!context.mounted) return;

    if (solapados.isNotEmpty) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Solapamiento detectado'),
          content: Text(
            '${solapados.length} bloque(s) de la plantilla se solaparían '
            'con bloques existentes. ¿Quieres continuar de todas formas?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    // Genera las fechas de aplicación
    if (frecuencia != null) {
      // Aplica la primera vez manualmente
      await provider.aplicarPlantilla(plantilla.id!, fechaInicio);
      
      // Registra la repetición para las siguientes ocurrencias
      await RepeticionPlantillaService.instance.registrarRepeticion(
        plantillaId: plantilla.id!,
        frecuencia: frecuencia,
        fechaInicio: fechaInicio,
        ultimaFechaGenerada: fechaInicio,
        fechaLimite: fechaLimite,
      );
      await RepeticionPlantillaService.instance.procesarRepeticionesPendientes();
    } else {
      await provider.aplicarPlantilla(plantilla.id!, fechaInicio, fechaLimite: fechaLimite);
    }

    bloqueProvider.invalidarCache();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        'Plantilla "${plantilla.nombre}" aplicada')),
    );
  }
}