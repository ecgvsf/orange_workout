import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/exercise.dart';

typedef ExerciseTrailingBuilder =
    Widget? Function(BuildContext context, Exercise exercise, bool isSelected);

class ExerciseFilterableListView extends StatefulWidget {
  final Isar isar;
  final bool isCompoundOnly;
  final String? selectedExerciseName;
  final Set<int>? multiSelectedExerciseIds;
  final ValueChanged<Exercise>? onExerciseTap;
  final ExerciseTrailingBuilder? trailingBuilder;
  final EdgeInsetsGeometry padding;
  final String searchHint;

  const ExerciseFilterableListView({
    super.key,
    required this.isar,
    this.isCompoundOnly = false,
    this.selectedExerciseName,
    this.multiSelectedExerciseIds,
    this.onExerciseTap,
    this.trailingBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 30),
    this.searchHint = 'Cerca esercizio o muscolo...',
  });

  @override
  State<ExerciseFilterableListView> createState() =>
      _ExerciseFilterableListViewState();
}

class _ExerciseFilterableListViewState
    extends State<ExerciseFilterableListView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(
    0.0,
  );

  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  List<String> _availableGroups = const ['Tutti'];

  String _selectedGroup = 'Tutti';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double clamped = _scrollController.offset.clamp(0.0, 35.0);
    if (clamped != _scrollOffsetNotifier.value) {
      _scrollOffsetNotifier.value = clamped;
    }
  }

  Future<void> _loadExercises() async {
    List<Exercise> list;
    if (widget.isCompoundOnly) {
      list =
          await widget.isar.exercises
              .filter()
              .isCompoundEqualTo(true)
              .sortByName()
              .findAll();
    } else {
      list = await widget.isar.exercises.where().sortByName().findAll();
    }

    final groups =
    list
        .map((e) {
      final g = e.muscleGroup.trim();
      if (g.isEmpty) return g;
      // Capitalizza automaticamente la prima lettera
      return g[0].toUpperCase() + g.substring(1);
    })
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
    // Ordina alfabeticamente ignorando la differenza tra maiuscole e minuscole
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));


    if (mounted) {
      setState(() {
        _allExercises = list;
        _availableGroups = ['Tutti', ...groups];
        _updateFilteredList();
        _isLoading = false;
      });
    }
  }

  void _updateFilteredList() {
    final q = _searchQuery.trim().toLowerCase();
    final groupQuery = _selectedGroup.toLowerCase();

    // 1. Filtra gli esercizi in base alla ricerca e al gruppo
    List<Exercise> filtered =
        _allExercises.where((ex) {
          final matchesGroup =
              _selectedGroup == 'Tutti' ||
              ex.muscleGroup.toLowerCase() == groupQuery ||
              ex.secondaryMuscles.any((sec) => sec.toLowerCase() == groupQuery);

          final matchesSearch =
              q.isEmpty ||
              ex.name.toLowerCase().contains(q) ||
              ex.muscleGroup.toLowerCase().contains(q) ||
              ex.secondaryMuscles.any((sec) => sec.toLowerCase().contains(q));

          return matchesGroup && matchesSearch;
        }).toList();

    // 2. Ordina la lista mettendo i muscoli primari in cima
    if (_selectedGroup != 'Tutti') {
      filtered.sort((a, b) {
        final aIsPrimary = a.muscleGroup.toLowerCase() == groupQuery;
        final bIsPrimary = b.muscleGroup.toLowerCase() == groupQuery;

        if (aIsPrimary && !bIsPrimary) {
          return -1; // 'a' sale (è primario)
        } else if (!aIsPrimary && bIsPrimary) {
          return 1; // 'b' sale (è primario)
        } else {
          // Se entrambi sono primari (o entrambi secondari), mantieni l'ordine alfabetico
          return a.name.compareTo(b.name);
        }
      });
    }

    _filteredExercises = filtered;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF9700)),
      );
    }

    return Column(
      children: [
        // 1. Barra di ricerca dark con icona arancione e clear rapido
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: _searchController,
              // 1. Allinea il cursore e il testo al centro verticale del campo
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFFFF9700),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                // 2. Compressione verticale compatta e centrata
                isDense: true,
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 46,
                  minHeight: 46,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFFF9700),
                  size: 22,
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _updateFilteredList();
                            });
                          },
                        )
                        : null,
                border: InputBorder.none,
                // 3. Padding verticale a zero (o ridotto) poiché l'altezza è guidata dall'icona e centrata
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _updateFilteredList();
                });
              },
            ),
          ),
        ),

        // 2. Chip orizzontali dei gruppi muscolari
        if (_availableGroups.length > 1) ...[
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _availableGroups.length,
              itemBuilder: (context, index) {
                final group = _availableGroups[index];
                final isSelected = group == _selectedGroup;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedGroup = group;
                      _updateFilteredList();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? const Color(0xFFFF9700)
                              : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        group,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 10),

        // 3. Lista Esercizi con ShaderMask ad alte prestazioni
        Expanded(
          child:
              _filteredExercises.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: Colors.white.withValues(alpha: 0.2),
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Nessun esercizio trovato',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Prova a modificare la ricerca o il filtro.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                  : ValueListenableBuilder<double>(
                    valueListenable: _scrollOffsetNotifier,
                    builder: (context, offset, child) {
                      final double scrollProgress = (offset / 35.0).clamp(
                        0.0,
                        1.0,
                      );
                      final double topFadePixels = 32.0 * scrollProgress;

                      return ShaderMask(
                        shaderCallback: (Rect bounds) {
                          final double topFadeStop =
                              (topFadePixels / bounds.height).clamp(0.0, 0.15);

                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(
                                alpha: 1.0 - scrollProgress,
                              ),
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: [0.0, topFadeStop, 0.92, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: child,
                      );
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: widget.padding,
                      itemCount: _filteredExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = _filteredExercises[index];
                        final bool isSelected =
                            (widget.selectedExerciseName != null &&
                                widget.selectedExerciseName == exercise.name) ||
                            (widget.multiSelectedExerciseIds != null &&
                                widget.multiSelectedExerciseIds!.contains(
                                  exercise.id,
                                ));

                        return _ModularExerciseCard(
                          key: ValueKey(exercise.id),
                          exercise: exercise,
                          isSelected: isSelected,
                          onTap:
                              widget.onExerciseTap != null
                                  ? () => widget.onExerciseTap!(exercise)
                                  : null,
                          trailing:
                              widget.trailingBuilder != null
                                  ? widget.trailingBuilder!(
                                    context,
                                    exercise,
                                    isSelected,
                                  )
                                  : null,
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

// Card Singola Ottimizzata con Rendering Immagine / Fallback Icona
class _ModularExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ModularExerciseCard({
    super.key,
    required this.exercise,
    required this.isSelected,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage =
        exercise.imagePath != null && File(exercise.imagePath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? const Color(0xFFFF9700).withValues(alpha: 0.12)
                : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected
                  ? const Color(0xFFFF9700)
                  : Colors.white.withValues(alpha: 0.04),
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icona o Immagine reale salvata
                // NUOVO CODICE:
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9700).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildThumbnail(exercise.imagePath),
                  ),
                ),
                const SizedBox(width: 12),

                // Titolo e Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? const Color(0xFFFF9700)
                                  : Colors.white,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.muscleGroup,
                              style: const TextStyle(
                                color: Color(0xFFFFB74D),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  exercise.isCompound
                                      ? const Color(
                                        0xFFFF9700,
                                      ).withValues(alpha: 0.2)
                                      : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.isCompound
                                  ? 'Multiarticolare'
                                  : 'Isolamento',
                              style: TextStyle(
                                color:
                                    exercise.isCompound
                                        ? const Color(0xFFFF9700)
                                        : Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (exercise.equipment != null &&
                              exercise.equipment!.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                exercise.equipment!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Slot personalizzato a destra (Puntini, Play, Spunta o Check circolare)
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? path) {
    const fallback = Icon(
      Icons.fitness_center_rounded,
      color: Color(0xFFFF9700),
      size: 20,
    );

    if (path == null || path.trim().isEmpty) {
      return fallback;
    }

    // Se l'immagine è negli asset del progetto (es. assets/...)
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    // Se l'immagine è un URL online
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    // Se è un file salvato su disco dalla galleria
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return fallback;
  }
}
