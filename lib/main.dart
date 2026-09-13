import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

// Importa il tema custom che abbiamo creato
import 'theme/app_theme.dart';

// Importa tutti i modelli dati
import 'models/exercise.dart';
import 'models/routine_template.dart';
import 'models/session.dart';
import 'models/workout_set.dart';
import 'models/user_profile.dart';
import 'pages/bottom_nav.dart';
import 'pages/home_screen.dart';
import 'pages/calendar_screen.dart';

void main() async {
  // Garantisce che i binding di Flutter siano inizializzati prima di usare plugin nativi (come il file system)
  WidgetsFlutterBinding.ensureInitialized();

  // Ottieni la directory sicura del dispositivo per salvare il database Isar
  final dir = await getApplicationDocumentsDirectory();

  // Apri il database Isar registrando tutti gli schemi generati
  final isar = await Isar.open([
    ExerciseSchema,
    RoutineTemplateSchema,
    SessionSchema,
    WorkoutSetSchema,
    UserProfileSchema,
  ], directory: dir.path);

  // Lancia l'app passando l'istanza del database
  runApp(WorkoutManagerApp(isar: isar));
}

class WorkoutManagerApp extends StatelessWidget {
  final Isar isar;

  const WorkoutManagerApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Manager',
      debugShowCheckedModeBanner: false, // Rimuove il banner di debug
      theme: workoutTheme, // Applica il tema scuro con l'arancione vibrante
      home: MainNavigationScreen(isar: isar),
    );
  }
}

// Struttura della schermata principale con la Bottom Navigation Bar
class MainNavigationScreen extends StatefulWidget {
  final Isar isar;

  const MainNavigationScreen({super.key, required this.isar});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Lista delle schermate dell'applicazione.
  // Per ora usiamo dei semplici "Center text" come segnaposto.
  late final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const Center(
      child: Text('Motore di Allenamento', style: TextStyle(fontSize: 24)),
    ),
    const Center(
      child: Text('Statistiche e Grafici', style: TextStyle(fontSize: 24)),
    ),
    const Center(child: Text('Profilo Utente', style: TextStyle(fontSize: 24))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // FONDAMENTALE: fa scorrere lo sfondo dietro la card
      backgroundColor: const Color(0xFF121212),
      body: _screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: FloatingWorkoutNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}
