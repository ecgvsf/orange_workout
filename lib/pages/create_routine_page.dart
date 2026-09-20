import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/exercise.dart';
import '../models/routine_template.dart';
import '../models/routine_item.dart';
import '../widgets/custom_dialog.dart';

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

  final List<RoutineExerciseConfig> _routineExercises = [];
  bool _hasUnsavedChanges = false;

  Map<String, int> get _volumePerMuscle {
    final Map<String, int> map = {};
    for (var ex in _routineExercises) {
      map[ex.muscleGroup] = (map[ex.muscleGroup] ?? 0) + ex.targetSets;
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

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

  int get _totalSets =>
      _routineExercises.fold(0, (sum, item) => sum + item.targetSets);

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
              // 1. LISTA SCORREVOLE A TUTTO SCHERMO
              ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 50),
                children: [
                  // --- 1. NOME DELLA SCHEDA ---
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

                  // --- 2. SELETTORE DELLO SPLIT (CHIPS MINIMALISTI) ---
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

                  // Note opzionali compattate
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

                  // --- 3. HEADER ESERCIZI CON RIEPILOGO IMMEDIATO ---
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

                  // --- 4. LISTA ESERCIZI ---
                  if (_routineExercises.isEmpty)
                    _buildEmptyPlaceholder()
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _routineExercises.length,
                      proxyDecorator: (
                        Widget child,
                        int index,
                        Animation<double> animation,
                      ) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (BuildContext context, Widget? child) {
                            return Material(
                              color: Colors.transparent,
                              elevation: 0,
                              borderRadius: BorderRadius.circular(18),
                              clipBehavior: Clip.antiAlias,
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
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
                        return _buildCleanExerciseCard(config, index);
                      },
                    ),
                  const SizedBox(height: 20),

                  // --- 5. RECAP DISTRETTI MUSCOLARI ---
                  const Text(
                    'Riepilogo Gruppi Muscolari',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildMuscleRecap(),
                ],
              ),

              // 2. SFUMATURA SUPERIORE (Attiva solo durante lo scorrimento, zero righe)
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

              // 3. SFUMATURA INFERIORE (Costante e morbida verso il bordo inferiore)
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

  Widget _buildCleanExerciseCard(RoutineExerciseConfig config, int index) {
    return Container(
      key: ValueKey('${config.exerciseId}_$index'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openExerciseQuickEditor(config),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.exerciseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${config.muscleGroup} ${config.isCompound ? '• Multiarticolare' : '• Isolamento'}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF9700).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${config.targetSets} × ${config.minReps}-${config.maxReps}',
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${config.restSeconds}s',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.white30,
                        size: 13,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _routineExercises.removeAt(index);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openExerciseQuickEditor(RoutineExerciseConfig config) {
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    config.exerciseName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Riga 1: Serie
                  _buildEditorRow(
                    label: 'Numero di Serie',
                    valueDisplay: '${config.targetSets}',
                    onMinus: () {
                      if (config.targetSets > 1) {
                        HapticFeedback.selectionClick();
                        setModalState(() => config.targetSets--);
                        setState(() => _hasUnsavedChanges = true);
                      }
                    },
                    onPlus: () {
                      if (config.targetSets < 15) {
                        HapticFeedback.selectionClick();
                        setModalState(() => config.targetSets++);
                        setState(() => _hasUnsavedChanges = true);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Riga 2: Ripetizioni Minime e Massime
                  Row(
                    children: [
                      Expanded(
                        child: _buildEditorRow(
                          label: 'Reps Min',
                          valueDisplay: '${config.minReps}',
                          onMinus: () {
                            if (config.minReps > 1) {
                              HapticFeedback.selectionClick();
                              setModalState(() => config.minReps--);
                              setState(() => _hasUnsavedChanges = true);
                            }
                          },
                          onPlus: () {
                            if (config.minReps < 40) {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                config.minReps++;
                                if (config.maxReps < config.minReps) {
                                  config.maxReps = config.minReps;
                                }
                              });
                              setState(() => _hasUnsavedChanges = true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildEditorRow(
                          label: 'Reps Max',
                          valueDisplay: '${config.maxReps}',
                          onMinus: () {
                            if (config.maxReps > 1) {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                config.maxReps--;
                                if (config.minReps > config.maxReps) {
                                  config.minReps = config.maxReps;
                                }
                              });
                              setState(() => _hasUnsavedChanges = true);
                            }
                          },
                          onPlus: () {
                            if (config.maxReps < 50) {
                              HapticFeedback.selectionClick();
                              setModalState(() => config.maxReps++);
                              setState(() => _hasUnsavedChanges = true);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Riga 3: Recupero Rapido a Chip
                  const Text(
                    'Tempo di Recupero',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children:
                          [30, 45, 60, 90, 120, 180].map((sec) {
                            final isSel = config.restSeconds == sec;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => config.restSeconds = sec);
                                setState(() => _hasUnsavedChanges = true);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSel
                                          ? const Color(0xFFFF9700)
                                          : const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        isSel
                                            ? Colors.transparent
                                            : Colors.white12,
                                  ),
                                ),
                                child: Text(
                                  '${sec}s',
                                  style: TextStyle(
                                    color:
                                        isSel ? Colors.white : Colors.white70,
                                    fontWeight:
                                        isSel
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Conferma',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  Widget _buildEditorRow({
    required String label,
    required String valueDisplay,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.remove_rounded,
                  color: Colors.white54,
                  size: 22,
                ),
                onPressed: onMinus,
              ),
              Text(
                valueDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFFFF9700),
                  size: 22,
                ),
                onPressed: onPlus,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openExerciseSelectorModal() async {
    final exercises =
        await widget.isar.exercises.where().sortByName().findAll();

    if (!mounted) return;

    if (exercises.isEmpty) {
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
    String query = '';

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
            final filtered =
                exercises
                    .where(
                      (e) =>
                          e.name.toLowerCase().contains(query.toLowerCase()) ||
                          e.muscleGroup.toLowerCase().contains(
                            query.toLowerCase(),
                          ),
                    )
                    .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Aggiungi Esercizi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (selectedExerciseIds.isNotEmpty)
                        Text(
                          '${selectedExerciseIds.length} selezionati',
                          style: const TextStyle(
                            color: Color(0xFFFF9700),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Cerca esercizio...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFFF9700),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF141414),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final ex = filtered[i];
                        final isSel = selectedExerciseIds.contains(ex.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color:
                                isSel
                                    ? const Color(
                                      0xFFFF9700,
                                    ).withValues(alpha: 0.1)
                                    : const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSel
                                      ? const Color(0xFFFF9700)
                                      : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              ex.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              ex.muscleGroup,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            trailing:
                                isSel
                                    ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFFFF9700),
                                      size: 20,
                                    )
                                    : const Icon(
                                      Icons.circle_outlined,
                                      color: Colors.white24,
                                      size: 20,
                                    ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                if (isSel) {
                                  selectedExerciseIds.remove(ex.id);
                                } else {
                                  selectedExerciseIds.add(ex.id);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          selectedExerciseIds.isEmpty
                              ? null
                              : () {
                                final picked =
                                    exercises
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
                                        ..targetSets = ex.isCompound ? 4 : 3
                                        ..minReps = ex.isCompound ? 6 : 8
                                        ..maxReps = ex.isCompound ? 8 : 12
                                        ..restSeconds =
                                            ex.isCompound ? 120 : 60,
                                    );
                                  }
                                  _hasUnsavedChanges = true;
                                });
                                Navigator.pop(ctx);
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  Widget _buildMuscleRecap() {
    final Map<String, int> distretti = _volumePerMuscle;
    if (distretti.isEmpty) return const SizedBox.shrink();

    final sortedEntries =
        distretti.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final int total = _totalSets;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9700).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFFFF9700),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volume per Gruppo Muscolare',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ripartizione delle serie allenanti nella scheda',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  '$total set',
                  style: const TextStyle(
                    color: Color(0xFFFF9700),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),
          ...sortedEntries.map((entry) {
            final double percentage = total > 0 ? (entry.value / total) : 0.0;
            final bool isDominant = percentage >= 0.40;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${entry.value} ${entry.value == 1 ? 'set' : 'set'}',
                            style: TextStyle(
                              color:
                                  isDominant
                                      ? const Color(0xFFFF9700)
                                      : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${(percentage * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 7,
                      width: double.infinity,
                      color: const Color(0xFF141414),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percentage.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isDominant
                                    ? const Color(0xFFFF9700)
                                    : const Color(0xFFFFB74D),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
