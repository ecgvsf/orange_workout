import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
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

  // Catalogo unificato dei gruppi muscolari
  final List<String> _muscleCategories = const [
    'Petto',
    'Dorso',
    'Alta Schiena',
    'Lombari',
    'Spalle',
    'Bicipiti',
    'Tricipiti',
    'Quadricipiti',
    'Femorali',
    'Glutei',
    'Polpacci',
    'Addome',
  ];

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

            // --- FILTRO GRUPPI MUSCOLARI ---
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
                              color: isSelected ? Colors.white : Colors.white70,
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
            ],

            // Spaziatore pulito senza interruzioni trasparenti
            const SizedBox(height: 10),

            // --- LISTA CON FADE FLUIDO SUPERIORE E INFERIORE ---
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
                          final double scrollProgress =
                              (_topScrollOffset / 35.0).clamp(0.0, 1.0);
                          final double topFadePixels = 32.0 * scrollProgress;
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
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          // top a 0 per azzerare fessure vuote in cima
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 95),
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

  // --- CARD ESERCIZIO ---
  Widget _buildExerciseItemCard(Exercise exercise) {
    final bool hasImage =
        exercise.imagePath != null && File(exercise.imagePath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9700).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  hasImage
                      ? Image.file(
                        File(exercise.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.fitness_center_rounded,
                              color: Color(0xFFFF9700),
                              size: 22,
                            ),
                      )
                      : const Icon(
                        Icons.fitness_center_rounded,
                        color: Color(0xFFFF9700),
                        size: 22,
                      ),
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
                if (exercise.isCompound &&
                    exercise.secondaryMuscles.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Secondari: ${exercise.secondaryMuscles.join(', ')}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
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

  // --- MODALE DI CREAZIONE / MODIFICA CON DROPDOWN A CARD E BORDI ARROTONDATI ---
  void _openExerciseModal({Exercise? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String selectedMuscle = existing?.muscleGroup ?? _muscleCategories.first;
    bool isCompound = existing?.isCompound ?? false;
    String selectedEquipment = existing?.equipment ?? 'Bilanciere';
    String? currentImagePath = existing?.imagePath;

    final List<String> selectedSecondaryMuscles =
        existing != null ? List<String>.from(existing.secondaryMuscles) : [];

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
            final List<String> availableSecondaryCategories =
                _muscleCategories.where((m) => m != selectedMuscle).toList();

            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 34,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Maniglia
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
                    const SizedBox(height: 20),

                    // --- SELETTORE IMMAGINE QUADRATO E CENTRATO ---
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final XFile? pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 900,
                            maxHeight: 900,
                            imageQuality: 85,
                          );

                          if (pickedFile != null) {
                            final appDir =
                                await getApplicationDocumentsDirectory();
                            final String fileName =
                                'ex_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            final File permanentFile = await File(
                              pickedFile.path,
                            ).copy('${appDir.path}/$fileName');

                            setModalState(() {
                              currentImagePath = permanentFile.path;
                            });
                          }
                        },
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  currentImagePath != null
                                      ? const Color(
                                        0xFFFF9700,
                                      ).withValues(alpha: 0.6)
                                      : Colors.white12,
                              width: 1.5,
                            ),
                          ),
                          child:
                              currentImagePath != null &&
                                      File(currentImagePath!).existsSync()
                                  ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Image.file(
                                          File(currentImagePath!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              currentImagePath = null;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                  : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_rounded,
                                        color: const Color(
                                          0xFFFF9700,
                                        ).withValues(alpha: 0.85),
                                        size: 38,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Aggiungi Foto',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Galleria',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- NOME ESERCIZIO ---
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
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- ROW DEI DUE DROPDOWN (GRUPPO MUSCOLARE + ATTREZZATURA) ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. GRUPPO MUSCOLARE PRIMARIO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gruppo Target',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      splashFactory: NoSplash.splashFactory,
                                    ),
                                    child: DropdownButton<String>(
                                      value:
                                          _muscleCategories.contains(
                                                selectedMuscle,
                                              )
                                              ? selectedMuscle
                                              : _muscleCategories.first,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(18),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFFFF9700),
                                        size: 22,
                                      ),
                                      selectedItemBuilder: (context) {
                                        return _muscleCategories.map((group) {
                                          return Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFF9700,
                                                  ).withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .accessibility_new_rounded,
                                                  color: Color(0xFFFF9700),
                                                  size: 15,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  group,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList();
                                      },
                                      items:
                                          _muscleCategories.map((group) {
                                            final isSelected =
                                                group == selectedMuscle;
                                            return DropdownMenuItem<String>(
                                              value: group,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      isSelected
                                                          ? const Color(
                                                            0xFFFF9700,
                                                          ).withValues(
                                                            alpha: 0.12,
                                                          )
                                                          : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? const Color(
                                                              0xFFFF9700,
                                                            )
                                                            : Colors
                                                                .transparent,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      group,
                                                      style: TextStyle(
                                                        color:
                                                            isSelected
                                                                ? const Color(
                                                                  0xFFFF9700,
                                                                )
                                                                : Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            isSelected
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .normal,
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      const Icon(
                                                        Icons.check_rounded,
                                                        color: Color(
                                                          0xFFFF9700,
                                                        ),
                                                        size: 16,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          HapticFeedback.selectionClick();
                                          setModalState(() {
                                            selectedMuscle = v;
                                            selectedSecondaryMuscles.remove(v);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // 2. ATTREZZATURA
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      splashFactory: NoSplash.splashFactory,
                                    ),
                                    child: DropdownButton<String>(
                                      value:
                                          equipmentOptions.contains(
                                                selectedEquipment,
                                              )
                                              ? selectedEquipment
                                              : equipmentOptions.first,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(18),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFFFF9700),
                                        size: 22,
                                      ),
                                      selectedItemBuilder: (context) {
                                        return equipmentOptions.map((eq) {
                                          return Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFF9700,
                                                  ).withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.fitness_center_rounded,
                                                  color: Color(0xFFFF9700),
                                                  size: 15,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  eq,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList();
                                      },
                                      items:
                                          equipmentOptions.map((eq) {
                                            final isSelected =
                                                eq == selectedEquipment;
                                            return DropdownMenuItem<String>(
                                              value: eq,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      isSelected
                                                          ? const Color(
                                                            0xFFFF9700,
                                                          ).withValues(
                                                            alpha: 0.12,
                                                          )
                                                          : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? const Color(
                                                              0xFFFF9700,
                                                            )
                                                            : Colors
                                                                .transparent,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      eq,
                                                      style: TextStyle(
                                                        color:
                                                            isSelected
                                                                ? const Color(
                                                                  0xFFFF9700,
                                                                )
                                                                : Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            isSelected
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .normal,
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      const Icon(
                                                        Icons.check_rounded,
                                                        color: Color(
                                                          0xFFFF9700,
                                                        ),
                                                        size: 16,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          HapticFeedback.selectionClick();
                                          setModalState(
                                            () => selectedEquipment = v,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- SWITCH MULTIARTICOLARE (COMPOUND) ---
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Esercizio Multiarticolare (Compound)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Coinvolge più articolazioni e muscoli secondari (1RM)',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      value: isCompound,
                      activeColor: const Color(0xFFFF9700),
                      onChanged: (v) {
                        setModalState(() {
                          isCompound = v;
                          if (!isCompound) {
                            selectedSecondaryMuscles.clear();
                          }
                        });
                      },
                    ),

                    // --- SEZIONE MUSCOLI SECONDARI (CONDIZIONALE) ---
                    if (isCompound) ...[
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Muscoli Secondari / Sinergici',
                            style: TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${selectedSecondaryMuscles.length} selezionati',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            availableSecondaryCategories.map((muscle) {
                              final isSelected = selectedSecondaryMuscles
                                  .contains(muscle);
                              return FilterChip(
                                label: Text(muscle),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      selectedSecondaryMuscles.add(muscle);
                                    } else {
                                      selectedSecondaryMuscles.remove(muscle);
                                    }
                                  });
                                },
                                labelStyle: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.black
                                          : Colors.white70,
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                                selectedColor: const Color(0xFFFF9700),
                                backgroundColor: const Color(0xFF141414),
                                checkmarkColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color:
                                        isSelected
                                            ? Colors.transparent
                                            : Colors.white12,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],

                    const SizedBox(height: 26),

                    // --- PULSANTE SALVA ---
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
                          target.imagePath = currentImagePath;
                          target.secondaryMuscles =
                              isCompound ? selectedSecondaryMuscles : [];

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
                            color: Colors.white,
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
