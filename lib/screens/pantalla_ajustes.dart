import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/exportar_service.dart';
import '../providers/categoria_provider.dart';
import '../providers/calendario_provider.dart';

import '../main.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context) {
    final temaProvider = context.watch<TemaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        children: [

          // ── Tema ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Apariencia',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),

          RadioListTile<TipoTema>(
            title: const Text('Claro'),
            secondary: const Icon(Icons.light_mode_outlined),
            value: TipoTema.claro,
            groupValue: temaProvider.tema,
            onChanged: (v) => temaProvider.cambiarTema(v!),
          ),

          RadioListTile<TipoTema>(
            title: const Text('Oscuro'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: TipoTema.oscuro,
            groupValue: temaProvider.tema,
            onChanged: (v) => temaProvider.cambiarTema(v!),
          ),

          RadioListTile<TipoTema>(
            title: const Text('Oscuro (AMOLED)'),
            subtitle: const Text('Fondo negro puro, ahorra batería en pantallas OLED'),
            secondary: const Icon(Icons.nights_stay_outlined),
            value: TipoTema.amoled,
            groupValue: temaProvider.tema,
            onChanged: (v) => temaProvider.cambiarTema(v!),
          ),

          const Divider(),

          // ── Notificaciones (próximamente) ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Notificaciones',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones'),
            subtitle: const Text('Próximamente'),
            enabled: false,
          ),

          const Divider(),

          // ── Calendario ──────────────────────────────────────────────────────

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Calendario',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),

          Consumer<CalendarioProvider>(
            builder: (context, calProvider, _) {
              if (!calProvider.permisoConcedido) {
                return ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Sincronizar con calendario'),
                  subtitle: const Text('Toca para conceder permisos'),
                  onTap: () => calProvider.inicializar(),
                );
              }

              return Column(
                children: calProvider.calendarios.map((cal) {
                  final activo = calProvider.calendariosActivos.contains(cal.id);
                  return SwitchListTile(
                    title: Text(cal.name ?? 'Calendario'),
                    secondary: CircleAvatar(
                      backgroundColor: cal.color != null
                          ? Color(cal.color!)
                          : Colors.grey,
                      radius: 10,
                    ),
                    value: activo,
                    onChanged: (_) => calProvider.toggleCalendario(cal.id!),
                  );
                }).toList(),
              );
            },
          ),

          // ── Datos (próximamente) ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Datos',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.upload_outlined),
              title: const Text('Exportar JSON'),
              onTap: () async {
                await ExportarService.instance.exportarJSON(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Exportar CSV'),
              onTap: () async {
                await ExportarService.instance.exportarCSV(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Importar JSON'),
              onTap: () async {
                final resultado = await ExportarService.instance.importarJSON();
                if (!context.mounted) return;
                if (resultado.exito) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Importados ${resultado.bloques} bloques y ${resultado.categorias} categorías'),
                  ));
                  context.read<CategoriaProvider>().cargarCategorias();
                } else if (resultado.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: ${resultado.error}'),
                  ));
                }
              },
            ),
        ],
      ),
    );
  }
}