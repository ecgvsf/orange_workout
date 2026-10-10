import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'pages/start_workout_sheet.dart';

import 'services/apple_live_activity.dart';
import 'services/workout_notification_service.dart';

void main() async {
  // Obbligatorio per permettere chiamate native asincrone prima di runApp
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    await AppleLiveActivityService.init();
  }
  await WorkoutNotificationService().init();
  // Inizializza notifiche locali

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

final ValueNotifier<int> globalRefreshNotifier = ValueNotifier<int>(0);

class MainNavigationScreen extends StatefulWidget {
  final Isar isar;

  const MainNavigationScreen({super.key, required this.isar});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime _selectedWorkoutDate = DateTime.now();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // 1. Controller per la dissolvenza pulita tra le tab
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _fadeController.value = 1.0; // Parte visibile

    // 2. Le 4 schermate vengono istanziate e mantenute in vita
    _screens = [
      HomeScreen(isar: widget.isar),
      CalendarScreen(
        isar: widget.isar,
        onDateSelected: (date) => _selectedWorkoutDate = date,
      ),
      StatsScreen(isar: widget.isar),
      ProfileScreen(isar: widget.isar),
    ];
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Esegue il refresh sia delle SharedPreferences sia dei listener/dati delle schede
  Future<void> _handleGlobalRefresh() async {
    HapticFeedback.lightImpact();

    // 1. Ricarica forzata da disco delle SharedPreferences per invalidare la cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // 2. Incrementa il trigger notificando tutte le schede iscritte
    globalRefreshNotifier.value++;

    // Piccolo delay per una chiusura fluida del trigger
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _onTabSelected(int index) {
    if (index == 2) {
      // Tasto centrale "+": apri la modale di avvio allenamento
      final DateTime effectiveDate =
          (_currentIndex == 1) ? _selectedWorkoutDate : DateTime.now();

      StartWorkoutSheet.show(context, widget.isar, effectiveDate);
    } else {
      final targetIndex = index > 2 ? index - 1 : index;
      if (_currentIndex != targetIndex) {
        // Avvia la transizione a dissolvenza senza distruggere i grafici
        _fadeController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentIndex = targetIndex;
            });
            _fadeController.forward();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF000000),
      // IndexedStack preserva lo stato esatto di tutte le pagine,
      // mentre FadeTransition crea la transizione sfumata senza scorrimento
      body: RefreshIndicator(
        color: const Color(0xFFFF9700),
        backgroundColor: const Color(0xFF1E1E1E),
        strokeWidth: 2.5,
        // Disabilita l'elasticità/bouncing alla fine dello swipe
        notificationPredicate: (notification) => notification.depth == 0,
        onRefresh: _handleGlobalRefresh,
        child: ScrollConfiguration(
          // Rimuove qualsiasi effetto rimbalzo / glow elastico nei figli
          behavior: const ScrollBehavior().copyWith(
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            overscroll: false,
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: FloatingWorkoutNavBar(
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
          ),
        ),
      ),
    );
  }
}