import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'providers/bloque_provider.dart';
import 'providers/categoria_provider.dart';
import 'providers/subcategoria_provider.dart';
import 'screens/pantalla_principal.dart';
import 'screens/pantalla_categorias.dart';
import 'screens/pantalla_plantillas.dart';
import 'screens/pantalla_ajustes.dart';
import 'services/notificacion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/plantilla_provider.dart';
import 'package:timeblocking/providers/calendario_provider.dart';
import 'services/repeticion_plantilla_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await NotificacionService.instance.inicializar();
  await NotificacionService.instance.reprogramarTodas();
  await RepeticionPlantillaService.instance.procesarRepeticionesPendientes();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BloqueProvider()),
        ChangeNotifierProvider(create: (_) => CategoriaProvider()),
        ChangeNotifierProvider(create: (_) => SubcategoriaProvider()),
        ChangeNotifierProvider(create: (_) => TemaProvider()),
        ChangeNotifierProvider(create: (_) => PlantillaProvider()),
        ChangeNotifierProvider(create: (_) => CalendarioProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// ─── Provider de tema ─────────────────────────────────────────────────────────

enum TipoTema { claro, oscuro, amoled }

class TemaProvider extends ChangeNotifier {
  TipoTema _tema = TipoTema.claro;

  TemaProvider() {
    _cargarTema();
  }

  TipoTema get tema => _tema;

  Future<void> _cargarTema() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getInt('tema') ?? 0;
    _tema = TipoTema.values[valor];
    notifyListeners();
  }

  Future<void> cambiarTema(TipoTema tipo) async {
    _tema = tipo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tema', tipo.index);
    notifyListeners();
  }

  ThemeMode get themeMode {
    if (_tema == TipoTema.claro) return ThemeMode.light;
    return ThemeMode.dark;
  }

  Color get colorFondo {
    if (_tema == TipoTema.amoled) return Colors.black;
    return Colors.transparent;
  }

  bool get esAmoled => _tema == TipoTema.amoled;
}

// ─── App ──────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final temaProvider = context.watch<TemaProvider>();

    return MaterialApp(
      title: 'Time Blocking',
      debugShowCheckedModeBanner: false,
      themeMode: temaProvider.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          surface: temaProvider.esAmoled ? Colors.black : null,
        ),
        scaffoldBackgroundColor:
            temaProvider.esAmoled ? Colors.black : null,
        useMaterial3: true,
      ),
      home: const NavegacionPrincipal(),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

// ─── Navegación principal con barra inferior ──────────────────────────────────

class NavegacionPrincipal extends StatefulWidget {
  const NavegacionPrincipal({super.key});

  @override
  State<NavegacionPrincipal> createState() => _NavegacionPrincipalState();
}

class _NavegacionPrincipalState extends State<NavegacionPrincipal> {
  int _indice = 0;

  final List<Widget> _pantallas = const [
    PantallaPrincipal(),
    PantallaCategorias(),
    PantallaPlantillas(),
    PantallaAjustes(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: _pantallas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.label_outline),
            selectedIcon: Icon(Icons.label),
            label: 'Categorías',
          ),
          NavigationDestination(
            icon: Icon(Icons.copy_outlined),
            selectedIcon: Icon(Icons.copy),
            label: 'Plantillas',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}