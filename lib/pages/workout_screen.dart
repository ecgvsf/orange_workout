import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/exercise.dart';
import '../widgets/exercise_filterable_list_view.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/exercise_form_sheet.dart';

class ExercisesScreen extends StatefulWidget {
  final Isar isar;

  const ExercisesScreen({super.key, required this.isar});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _exercisesSubscription;

  List<Exercise> _allExercises = [];
  bool _isLoading = true;
  double _topScrollOffset = 0.0;

  String _selectedGroup = 'Tutti';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchExercisesFromDb();
    _scrollController.addListener(_onScroll);

    // Ascolto reattivo delle modifiche su Isar
    _exercisesSubscription = widget.isar.exercises.watchLazy().listen((_) {
      _fetchExercisesFromDb(showSpinner: false);
    });
  }

  void _onScroll() {
    final double offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final double clamped = offset.clamp(0.0, 35.0);
    if (clamped != _topScrollOffset) {
      setState(() => _topScrollOffset = clamped);
    }
  }

  @override
  void dispose() {
    _exercisesSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExercisesFromDb({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final exercises =
        await widget.isar.exercises.where().sortByName().findAll();

    if (mounted) {
      setState(() {
        _allExercises = exercises;
        _isLoading = false;
      });
    }
  }

  List<String> get _availableFilterGroups {
    final groupsInDb =
        _allExercises
            .map((e) => e.muscleGroup.trim())
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['Tutti', ...groupsInDb];
  }

  List<Exercise> get _filteredExercises {
    return _allExercises.where((ex) {
      // 1. Corrisponde se selezioni "Tutti"
      // 2. O se corrisponde al muscolo principale (muscleGroup)
      // 3. O se è presente nei muscoli secondari (secondaryMuscles)
      final matchesGroup =
          _selectedGroup == 'Tutti' ||
          ex.muscleGroup.toLowerCase() == _selectedGroup.toLowerCase() ||
          ex.secondaryMuscles.any(
            (sec) => sec.toLowerCase() == _selectedGroup.toLowerCase(),
          );

      final matchesSearch =
          ex.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ex.muscleGroup.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ex.secondaryMuscles.any(
            (sec) => sec.toLowerCase() == _selectedGroup.toLowerCase(),
          );
      return matchesGroup && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final availableGroups = _availableFilterGroups;
    if (!availableGroups.contains(_selectedGroup)) {
      _selectedGroup = 'Tutti';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER CON TASTO INDIETRO ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).maybePop();
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        splashRadius: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Esercizi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLoading
                                ? 'Caricamento dal database...'
                                : '${_allExercises.length} esercizi nel database',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openExerciseModal(),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Nuovo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            const Divider(color: Color(0xFFFF9700), thickness: 1, height: 1),
            const SizedBox(height: 12),

            // Lista filtrabile con PopupMenuButton per ogni esercizio
            Expanded(
              child: ExerciseFilterableListView(
                isar: widget.isar,
                trailingBuilder: (context, exercise, _) {
                  return PopupMenuButton<String>(
                    color: const Color(0xFF252528),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openExerciseModal(existing: exercise);
                      } else if (value == 'delete') {
                        _confirmDeleteExercise(exercise);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Center(
                              child: Text(
                                'Modifica',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Center(
                              child: Text(
                                'Elimina',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODALE DI CREAZIONE / MODIFICA CON DROPDOWN A CARD E BORDI ARROTONDATI ---
  void _openExerciseModal({Exercise? existing}) {
    ExerciseFormSheet.show(context, isar: widget.isar, existing: existing);
  }

  Future<void> _confirmDeleteExercise(Exercise exercise) async {
    // Mostra il dialog custom di conferma con badge rosso/warning e 2 tasti
    final confirmed = await AppDialog.show(
      context,
      type: AppDialogType.error,
      title: 'Elimina Esercizio',
      message: 'Vuoi davvero eliminare "${exercise.name}" dal database?',
      primaryButtonText: 'Elimina',
      secondaryButtonText: 'Annulla',
    );

    // Se l'utente preme "Elimina", procede con la rimozione da Isar
    if (confirmed == true) {
      await widget.isar.writeTxn(() async {
        await widget.isar.exercises.delete(exercise.id);
      });

      if (mounted) {
        // Notifica di avvenuta eliminazione coerente (senza SnackBar)
        await AppDialog.show(
          context,
          type: AppDialogType.success,
          title: 'Eliminato',
          message: '${exercise.name} è stato rimosso dal database.',
          primaryButtonText: 'OK',
        );
      }
    }
  }
}
