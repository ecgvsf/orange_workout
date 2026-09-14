import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

// 1. Importa il tema
import 'theme/app_theme.dart';

// 2. Importa tutti gli schemi dei modelli
import 'models/exercise.dart';
import 'models/routine_template.dart';
import 'models/session.dart';
import 'models/workout_set.dart';
import 'models/user_profile.dart';

import 'constants/seed.dart';

// 3. Importa le schermate
import 'pages/home_screen.dart';
import 'pages/calendar_screen.dart';
import 'pages/profile_screen.dart';
import 'pages/bottom_nav.dart';
import 'pages/stats_screen.dart';
import 'pages/workout_engine_screen.dart';

void main() async {
  // Obbligatorio per permettere chiamate native asincrone prima di runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Ottiene la cartella locale del dispositivo in cui salvare il database
  final dir = await getApplicationDocumentsDirectory();

  // Apre l'istanza Isar registrando tutti gli schemi
  final isar = await Isar.open([
    ExerciseSchema,
    RoutineTemplateSchema,
    SessionSchema,
    WorkoutSetSchema,
    UserProfileSchema,
  ], directory: dir.path);

  await seedInitialExercises(isar);

  // Avvia l'applicazione passando l'istanza del database
  runApp(WorkoutManagerApp(isar: isar));
}

class WorkoutManagerApp extends StatelessWidget {
  final Isar isar;

  const WorkoutManagerApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Manager',
      debugShowCheckedModeBanner: false,
      theme: workoutTheme,
      home: MainNavigationScreen(isar: isar),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final Isar isar;

  const MainNavigationScreen({super.key, required this.isar});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // Indice memorizzato per la navbar (0: Home, 1: Calendario, 3: Stats, 4: Profilo)
  int _navBarIndex = 0;

  // Solo le 4 schermate a scorrimento orizzontale/tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(isar: widget.isar), // Indice interno 0
      CalendarScreen(isar: widget.isar), // Indice interno 1
      StatsScreen(isar: widget.isar), // Indice interno 2
      ProfileScreen(isar: widget.isar), // Indice interno 3
    ];
  }

  // Converte l'indice ricevuto dalla navbar (0, 1, 3, 4) nell'indice della lista (0, 1, 2, 3)
  int _mapNavBarIndexToScreenIndex(int navIndex) {
    switch (navIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Calendario
      case 3:
        return 2; // Stats
      case 4:
        return 3; // Profilo
      default:
        return 0;
    }
  }

  void _onNavBarTapped(int index) {
    if (index == 2) {
      // TASTO "+": Apre la schermata come nuova pagina modale
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog:
              true, // Animazione dal basso verso l'alto tipica delle modali
          builder: (context) => WorkoutEngineScreen(isar: widget.isar),
        ),
      );
    } else {
      // Altri tasti: cambiano la tab corrente senza resettare la pagina
      setState(() {
        _navBarIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int screenIndex = _mapNavBarIndexToScreenIndex(_navBarIndex);

    return Scaffold(
      extendBody:
          true, // Permette ai contenuti di scorrere dietro la card fluttuante
      backgroundColor: const Color(0xFF121212),
      body: _screens[screenIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: FloatingWorkoutNavBar(
            currentIndex: _navBarIndex,
            onTap: _onNavBarTapped,
          ),
        ),
      ),
    );
  }
}
