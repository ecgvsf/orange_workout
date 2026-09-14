import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/exercise.dart';

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

  // Categorie muscolari standard per la categorizzazione/creazione
  final List<String> _muscleCategories = const [
    'Petto',
    'Dorso',
    'Gambe',
    'Spalle',
    'Bicipiti',
    'Tricipiti',
    'Addome',
  ];

  @override
  void initState() {
    super.initState();
    _fetchExercisesFromDb();
    _scrollController.addListener(_onScroll);

    // Ascolta modifiche/inserimenti/cancellazioni nel DB in tempo reale
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

  /// Estrazione di tutti gli esercizi salvati in Isar ordinati per nome
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

  /// Estrae dinamicamente i gruppi muscolari presenti tra gli esercizi del DB
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

  /// Filtraggio per gruppo muscolare e stringa di ricerca
  List<Exercise> get _filteredExercises {
    return _allExercises.where((ex) {
      final matchesGroup =
          _selectedGroup == 'Tutti' ||
          ex.muscleGroup.toLowerCase() == _selectedGroup.toLowerCase();
      final matchesSearch = ex.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
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

    // Calcolo opacità superiore dinamica: 1.0 a riposo (nessuna sfumatura), sfuma verso 0.0 con lo scroll
    final double topStartOpacity = (1.0 - (_topScrollOffset / 35.0)).clamp(
      0.0,
      1.0,
    );

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
                      // Tasto per tornare indietro
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
                      color: Colors.black,
                      size: 20,
                    ),
                    label: const Text(
                      'Nuovo',
                      style: TextStyle(
                        color: Colors.black,
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

            // --- SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Cerca esercizio...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
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
                              setState(() => _searchQuery = '');
                            },
                          )
                          : null,
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --- FILTRO GRUPPI MUSCOLARI DINAMICO DA DB ---
            if (availableGroups.length > 1) ...[
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: availableGroups.length,
                  itemBuilder: (context, index) {
                    final group = availableGroups[index];
                    final isSelected = group == _selectedGroup;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedGroup = group);
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
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.transparent
                                    : Colors.white12,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            group,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
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
            ],

            // --- LISTA ESERCIZI CON FADE FLUIDO SENZA RIGA TRASPARENTE ---
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF9700),
                        ),
                      )
                      : _allExercises.isEmpty
                      ? _buildNoDatabaseEntriesState()
                      : _filteredExercises.isEmpty
                      ? _buildEmptyFilteredState()
                      : ShaderMask(
                        shaderCallback: (Rect bounds) {
                          // Progress: 0.0 a lista ferma in cima, 1.0 dopo 15px di scorrimento
                          final double scrollProgress =
                              (_topScrollOffset / 15.0).clamp(0.0, 1.0);

                          // Altezza del fade superiore: 0px a riposo, fino a 40 durante lo scroll
                          final double topFadePixels = 40.0 * scrollProgress;
                          final double topFadeStop =
                              (topFadePixels / bounds.height).clamp(0.0, 0.15);

                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              // A riposo = nero opaco (nessuna riga/taglio).
                              // Man mano che scorri verso il basso = sfuma dolcemente a trasparente.
                              Colors.black.withValues(
                                alpha: 1.0 - scrollProgress,
                              ),
                              Colors.black,
                              Colors.black,
                              Colors
                                  .transparent, // Fade morbido in basso verso la navbar
                            ],
                            stops: [
                              0.0,
                              topFadeStop, // Si espande dolcemente dai bordi solo allo scroll
                              0.92,
                              1.0,
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          // TOP A ZERO: elimina qualsiasi micro-fessura o padding fantasma in cima!
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
                          itemCount: _filteredExercises.length,
                          itemBuilder: (context, index) {
                            return _buildExerciseItemCard(
                              _filteredExercises[index],
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItemCard(Exercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9700).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: Color(0xFFFF9700),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            exercise.isCompound
                                ? const Color(0xFFFF9700).withValues(alpha: 0.2)
                                : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exercise.isCompound ? 'Multiarticolare' : 'Isolamento',
                        style: TextStyle(
                          color:
                              exercise.isCompound
                                  ? const Color(0xFFFF9700)
                                  : Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (exercise.equipment != null &&
                        exercise.equipment!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
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
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text('Modifica', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Elimina',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDatabaseEntriesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 64,
            ),
            const SizedBox(height: 14),
            const Text(
              'Nessun esercizio nel database',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Il database locale è vuoto. Tocca "+ Nuovo" in alto per creare il tuo primo esercizio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: 54,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nessun risultato trovato',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Prova a modificare i filtri o la ricerca.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --- MODALE DI CREAZIONE / MODIFICA SU ISAR ---
  void _openExerciseModal({Exercise? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String selectedMuscle = existing?.muscleGroup ?? _muscleCategories.first;
    bool isCompound = existing?.isCompound ?? false;
    String selectedEquipment = existing?.equipment ?? 'Bilanciere';

    final equipmentOptions = const [
      'Bilanciere',
      'Manubri',
      'Cavi',
      'Macchinario',
      'Corpo Libero',
      'Altro',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      existing == null
                          ? 'Nuovo Esercizio'
                          : 'Modifica Esercizio',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nome Esercizio
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Nome esercizio",
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF141414),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gruppo Muscolare Target
                    const Text(
                      'Gruppo Muscolare',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButton<String>(
                        value:
                            _muscleCategories.contains(selectedMuscle)
                                ? selectedMuscle
                                : _muscleCategories.first,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        items:
                            _muscleCategories.map((m) {
                              return DropdownMenuItem(value: m, child: Text(m));
                            }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => selectedMuscle = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Attrezzatura
                    const Text(
                      'Attrezzatura',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButton<String>(
                        value:
                            equipmentOptions.contains(selectedEquipment)
                                ? selectedEquipment
                                : equipmentOptions.first,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        items:
                            equipmentOptions.map((eq) {
                              return DropdownMenuItem(
                                value: eq,
                                child: Text(eq),
                              );
                            }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => selectedEquipment = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Flag Multiarticolare
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Esercizio Multiarticolare (Compound)',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Abilita il calcolo e il tracciamento del massimale 1RM',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      value: isCompound,
                      activeColor: const Color(0xFFFF9700),
                      onChanged: (v) => setModalState(() => isCompound = v),
                    ),
                    const SizedBox(height: 18),

                    // Pulsante Salva su Isar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9700),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          final target = existing ?? Exercise();
                          target.name = name;
                          target.muscleGroup = selectedMuscle;
                          target.isCompound = isCompound;
                          target.equipment = selectedEquipment;

                          await widget.isar.writeTxn(() async {
                            await widget.isar.exercises.put(target);
                          });

                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text(
                          'Salva nel Database',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Conferma ed eliminazione fisica da Isar
  void _confirmDeleteExercise(Exercise exercise) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Elimina Esercizio',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Vuoi davvero eliminare "${exercise.name}" dal database?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Annulla',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await widget.isar.writeTxn(() async {
                    await widget.isar.exercises.delete(exercise.id);
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${exercise.name} eliminato dal database',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text('Elimina'),
              ),
            ],
          ),
    );
  }
}
