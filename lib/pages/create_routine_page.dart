import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../models/exercise.dart';
import '../models/routine_template.dart';
import '../models/routine_item.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/exercise_filterable_list_view.dart';
import '../widgets/routine/routine_exercise_card.dart';
import '../widgets/routine/routine_volume_recap.dart';
import '../widgets/routine/routine_exercise_editor_sheet.dart';
import '../models/exercise_type.dart';

class CreateRoutineScreen extends StatefulWidget {
  final Isar isar;
  final RoutineTemplate? existingRoutine;

  const CreateRoutineScreen({
    super.key,
    required this.isar,
    this.existingRoutine,
  });

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final ScrollController _scrollController = ScrollController();
  double _topScrollOffset = 0.0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedMacroSplit = 'Push';
  final List<String> _macroSplits = const [
    'Push',
    'Pull',
    'Legs',
    'Upper',
    'Lower',
    'Full Body',
  ];

  Map<String, String?> _exerciseImages = {};

  final List<RoutineExerciseConfig> _routineExercises = [];
  bool _hasUnsavedChanges = false;

  Map<String, int> get _volumePerMuscle {
    final Map<String, int> map = {};
    for (var ex in _routineExercises) {
      map[ex.muscleGroup] = (map[ex.muscleGroup] ?? 0) + ex.targetSets;
    }
    return map;
  }

  int get _totalSets =>
      _routineExercises.fold(0, (sum, item) => sum + item.targetSets);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExerciseImages();

    if (widget.existingRoutine != null) {
      _nameController.text = widget.existingRoutine!.name;
      _notesController.text = widget.existingRoutine!.notes ?? '';
      _selectedMacroSplit = widget.existingRoutine!.macroSplit;
      _routineExercises.addAll(
        widget.existingRoutine!.exercises.map(
          (e) =>
              RoutineExerciseConfig()
                ..exerciseId = e.exerciseId
                ..exerciseName = e.exerciseName
                ..muscleGroup = e.muscleGroup
                ..isCompound = e.isCompound
                ..targetSets = e.targetSets
                ..minReps = e.minReps
                ..maxReps = e.maxReps
                ..restSeconds = e.restSeconds,
        ),
      );
    }

    _nameController.addListener(() => _hasUnsavedChanges = true);
    _notesController.addListener(() => _hasUnsavedChanges = true);
  }

  Future<void> _loadExerciseImages() async {
    final allExercises = await widget.isar.exercises.where().findAll();
    if (mounted) {
      setState(() {
        _exerciseImages = {
          for (var ex in allExercises)
            ex.name.trim().toLowerCase(): ex.imagePath,
        };
      });
    }
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges && _routineExercises.isEmpty) return true;

    final discard = await AppDialog.show(
      context,
      type: AppDialogType.warning,
      title: 'Modifiche non salvate',
      message:
          'Se esci ora, le modifiche apportate alla scheda andranno perse.',
      primaryButtonText: 'Esci',
      secondaryButtonText: 'Rimani',
    );

    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Text(
              widget.existingRoutine == null
                  ? 'Nuova Scheda'
                  : 'Modifica Scheda',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: TextButton(
                  onPressed: _saveRoutineToDb,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Salva',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 50),
                children: [
                  // Nome Scheda
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nome scheda (es. Push Day, Gambe A)',
                      hintStyle: const TextStyle(
                        color: Colors.white30,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Selettore Split
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _macroSplits.length,
                      itemBuilder: (context, idx) {
                        final split = _macroSplits[idx];
                        final isSelected = split == _selectedMacroSplit;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedMacroSplit = split;
                              _hasUnsavedChanges = true;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
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
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.transparent
                                        : Colors.white12,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                split,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.white60,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Note
                  TextField(
                    controller: _notesController,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Note o focus opzionale...',
                      hintStyle: const TextStyle(
                        color: Colors.white30,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white30,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Esercizi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Esercizi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_routineExercises.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFF9700,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_totalSets serie tot.',
                                style: const TextStyle(
                                  color: Color(0xFFFF9700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _openExerciseSelectorModal,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Aggiungi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9700),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lista Esercizi Ordinabile o Placeholder Vuoto
                  if (_routineExercises.isEmpty)
                    _buildEmptyPlaceholder()
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _routineExercises.length,
                      onReorder: (oldIndex, newIndex) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _routineExercises.removeAt(oldIndex);
                          _routineExercises.insert(newIndex, item);
                          _hasUnsavedChanges = true;
                        });
                      },
                      itemBuilder: (context, index) {
                        final config = _routineExercises[index];
                        final String? imgPath =
                            _exerciseImages[config.exerciseName
                                .trim()
                                .toLowerCase()];

                        return RoutineExerciseCard(
                          key: ValueKey('${config.exerciseId}_$index'),
                          config: config,
                          index: index,
                          imagePath: imgPath,
                          onTap:
                              () => RoutineExerciseEditorSheet.show(
                                context,
                                config: config,
                                onChanged:
                                    () => setState(
                                      () => _hasUnsavedChanges = true,
                                    ),
                              ),
                          onDelete: () {
                            setState(() {
                              _routineExercises.removeAt(index);
                              _hasUnsavedChanges = true;
                            });
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 20),

                  // Recap Volume
                  RoutineVolumeRecap(
                    volumePerMuscle: _volumePerMuscle,
                    totalSets: _totalSets,
                  ),
                ],
              ),

              // Dissolvenza superiore dinamica
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 48,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (_topScrollOffset / 30.0).clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF121212),
                            Color(0xCC121212),
                            Color(0x00121212),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Dissolvenza inferiore morbida
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 52,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFF121212),
                          Color(0xCC121212),
                          Color(0x00121212),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: const Column(
        children: [
          Icon(Icons.fitness_center_rounded, color: Colors.white24, size: 36),
          SizedBox(height: 12),
          Text(
            'Nessun esercizio inserito',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tocca "+ Aggiungi" per selezionare gli esercizi da includere.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openExerciseSelectorModal() async {
    final count = await widget.isar.exercises.count();
    if (!mounted) return;

    if (count == 0) {
      AppDialog.show(
        context,
        type: AppDialogType.info,
        title: 'Catalogo Vuoto',
        message:
            'Non ci sono esercizi registrati. Creane prima qualcuno dalla libreria.',
        primaryButtonText: 'Ho capito',
      );
      return;
    }

    final Set<int> selectedExerciseIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Aggiungi Esercizi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedExerciseIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF9700,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${selectedExerciseIds.length} selezionati',
                              style: const TextStyle(
                                color: Color(0xFFFF9700),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ExerciseFilterableListView(
                      isar: widget.isar,
                      searchHint: 'Cerca esercizio...',
                      multiSelectedExerciseIds: selectedExerciseIds,
                      onExerciseTap: (exercise) {
                        HapticFeedback.selectionClick();
                        setModalState(() {
                          if (selectedExerciseIds.contains(exercise.id)) {
                            selectedExerciseIds.remove(exercise.id);
                          } else {
                            selectedExerciseIds.add(exercise.id);
                          }
                        });
                      },
                      trailingBuilder: (context, exercise, isSelected) {
                        return Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isSelected
                                    ? const Color(0xFFFF9700)
                                    : Colors.transparent,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFFFF9700)
                                      : Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child:
                              isSelected
                                  ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.black,
                                    size: 16,
                                  )
                                  : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed:
                            selectedExerciseIds.isEmpty
                                ? null
                                : () async {
                                  final allEx =
                                      await widget.isar.exercises
                                          .where()
                                          .findAll();
                                  final picked =
                                      allEx
                                          .where(
                                            (e) => selectedExerciseIds.contains(
                                              e.id,
                                            ),
                                          )
                                          .toList();

                                  setState(() {
                                    for (final ex in picked) {
                                      _routineExercises.add(
                                        RoutineExerciseConfig()
                                          ..exerciseId = ex.id
                                          ..exerciseName = ex.name
                                          ..muscleGroup = ex.muscleGroup
                                          ..isCompound = ex.isCompound
                                          ..exerciseType =
                                              ex
                                                  .exerciseType // <-- Copia il tipo dall'esercizio
                                          ..targetSets = ex.isCompound ? 4 : 3
                                          ..minReps = ex.isCompound ? 6 : 8
                                          ..maxReps = ex.isCompound ? 8 : 12
                                          ..minSeconds =
                                              ex.exerciseType ==
                                                      ExerciseType.time
                                                  ? 30
                                                  : 0 // <-- Inizializza i secondi
                                          ..maxSeconds =
                                              ex.exerciseType ==
                                                      ExerciseType.time
                                                  ? 45
                                                  : 0
                                          ..restSeconds =
                                              ex.isCompound ? 120 : 60,
                                      );
                                    }
                                    _hasUnsavedChanges = true;
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9700),
                          disabledBackgroundColor: Colors.white12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          selectedExerciseIds.isEmpty
                              ? 'Seleziona almeno un esercizio'
                              : 'Aggiungi (${selectedExerciseIds.length})',
                          style: TextStyle(
                            color:
                                selectedExerciseIds.isEmpty
                                    ? Colors.white30
                                    : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveRoutineToDb() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      await AppDialog.show(
        context,
        type: AppDialogType.error,
        title: 'Nome Mancante',
        message: 'Assegna un nome alla scheda prima di salvarla.',
        primaryButtonText: 'Ho capito',
      );
      return;
    }

    if (_routineExercises.isEmpty) {
      await AppDialog.show(
        context,
        type: AppDialogType.error,
        title: 'Nessun Esercizio',
        message: 'Inserisci almeno un esercizio nella scheda.',
        primaryButtonText: 'Aggiungi ora',
        onPrimaryPressed: _openExerciseSelectorModal,
      );
      return;
    }

    final routine = widget.existingRoutine ?? RoutineTemplate();
    routine.name = name;
    routine.notes = _notesController.text.trim();
    routine.macroSplit = _selectedMacroSplit;
    routine.exercises = _routineExercises;

    await widget.isar.writeTxn(() async {
      await widget.isar.routineTemplates.put(routine);
    });

    if (!mounted) return;
    _hasUnsavedChanges = false;

    await AppDialog.show(
      context,
      type: AppDialogType.success,
      title: 'Scheda Salvata',
      message: 'La routine "$name" è pronta per i tuoi allenamenti.',
      primaryButtonText: 'Ottimo',
    );

    if (mounted) Navigator.pop(context, true);
  }
}
