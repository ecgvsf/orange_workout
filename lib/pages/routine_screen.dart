import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/routine_template.dart';
import '../pages/create_routine_page.dart';
import '../widgets/custom_dialog.dart';

class RoutinesScreen extends StatefulWidget {
  final Isar? isar;

  const RoutinesScreen({super.key, this.isar});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  // Controller per monitorare lo scorrimento della lista
  final ScrollController _scrollController = ScrollController();
  double _topScrollOffset = 0.0;

  StreamSubscription? _routinesSubscription;
  List<RoutineTemplate> _routines = [];
  bool _isLoading = true;

  String _selectedSplitFilter = 'Tutti';
  final List<String> _splitFilters = const [
    'Tutti',
    'Push',
    'Pull',
    'Legs',
    'Upper',
    'Lower',
    'Full Body',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchRoutines();

    // Ascolto in tempo reale delle modifiche nella collection di Isar
    if (widget.isar != null) {
      _routinesSubscription = widget.isar!.routineTemplates.watchLazy().listen((
        _,
      ) {
        _fetchRoutines(showSpinner: false);
      });
    }
  }

  void _onScroll() {
    final double offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final double clamped = offset.clamp(0.0, 30.0);
    if (clamped != _topScrollOffset) {
      setState(() => _topScrollOffset = clamped);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _routinesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchRoutines({bool showSpinner = true}) async {
    if (widget.isar == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final data =
        await widget.isar!.routineTemplates.where().sortByName().findAll();

    if (mounted) {
      setState(() {
        _routines = data;
        _isLoading = false;
      });
    }
  }

  List<RoutineTemplate> get _filteredRoutines {
    if (_selectedSplitFilter == 'Tutti') return _routines;
    return _routines
        .where(
          (r) =>
              r.macroSplit.toLowerCase() == _selectedSplitFilter.toLowerCase(),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 100.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // --- HEADER SUPERIORE ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).maybePop();
                        },
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Schede & Routine',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_routines.length} programmazioni attive',
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
                    onPressed: () => _openCreateRoutine(),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Nuova',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9700),
                      foregroundColor: Colors.black,
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

            const SizedBox(height: 10),
            const Divider(color: Color(0xFFFF9700), thickness: 1, height: 1),
            const SizedBox(height: 12),

            // --- FILTRO RAPIDO SPLIT (CHIP SCORREVOLI) ---
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _splitFilters.length,
                itemBuilder: (context, index) {
                  final filter = _splitFilters[index];
                  final isSelected = filter == _selectedSplitFilter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSplitFilter = filter);
                        }
                      },
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      backgroundColor: const Color(0xFF1E1E1E),
                      selectedColor: const Color(0xFFFF9700),
                      side: BorderSide(
                        color: isSelected ? Colors.transparent : Colors.white12,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // --- BODY: LISTA CON FADE DINAMICO SUPERIORE E INFERIORE ---
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF9700),
                        ),
                      )
                      : _filteredRoutines.isEmpty
                      ? _buildEmptyState()
                      : Stack(
                        children: [
                          // 1. LISTA SCORREVOLE DELLE SCHEDE
                          ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              6,
                              16,
                              bottomPadding,
                            ),
                            itemCount: _filteredRoutines.length,
                            itemBuilder: (context, index) {
                              final routine = _filteredRoutines[index];
                              return _buildRoutineCard(routine, index);
                            },
                          ),

                          // 2. SFUMATURA SUPERIORE (Attiva solo allo scroll, zero righe di taglio)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 38,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: (_topScrollOffset / 30.0).clamp(
                                  0.0,
                                  1.0,
                                ),
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

                          // 3. SFUMATURA INFERIORE (Morbida e costante verso il fondo)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 48,
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
          ],
        ),
      ),
    );
  }

  // --- CARD SCHEDA MODERNA & APRIBILE ---
  Widget _buildRoutineCard(RoutineTemplate routine, int index) {
    final exercises = routine.exercises;
    final int totalSets = exercises.fold<int>(
      0,
      (sum, item) => sum + item.targetSets,
    );

    // Stima della durata: serie * tempo recupero medio + 45s esecuzione
    final int totalRestSec = exercises.fold<int>(
      0,
      (sum, item) => sum + (item.targetSets * item.restSeconds),
    );
    final int estimatedMin =
        exercises.isEmpty
            ? 0
            : (((totalSets * 45) + totalRestSec) / 60).round() + 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      // Taglia qualsiasi contenuto o alone esattamente lungo la curva a raggio 22
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        // Azzeramento totale degli effetti di flash/splash rettangolari al tocco
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        child: ExpansionTile(
          initiallyExpanded: index == 0,
          iconColor: const Color(0xFFFF9700),
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  routine.macroSplit.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFF9700),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  routine.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                _buildBadge(
                  '${exercises.length} esercizi',
                  const Color(0xFF2C2C2E),
                  Colors.white70,
                ),
                const SizedBox(width: 6),
                _buildBadge(
                  '$totalSets set',
                  const Color(0xFF2C2C2E),
                  Colors.white70,
                ),
                const SizedBox(width: 6),
                _buildBadge(
                  '~$estimatedMin min',
                  const Color(0xFF2C2C2E),
                  const Color(0xFFFFB74D),
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            color: const Color(0xFF252528),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
            onSelected: (value) {
              if (value == 'edit') {
                _openCreateRoutine(routineToEdit: routine);
              } else if (value == 'delete') {
                _confirmDeleteRoutine(routine);
              } else if (value == 'start') {
                _startWorkout(routine);
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'start',
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFFFF9700),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Inizia Sessione',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Modifica Scheda',
                          style: TextStyle(color: Colors.white),
                        ),
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
                          size: 20,
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
          children: [
            if (routine.notes != null && routine.notes!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      color: Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        routine.notes!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Lista Esercizi Programmati
            ...exercises.map((config) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9700).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: Color(0xFFFF9700),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.exerciseName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${config.muscleGroup} • Rest: ${config.restSeconds}s',
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
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252528),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${config.targetSets} × ${config.minReps}-${config.maxReps}',
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // Tasto Rapido Inizia Allenamento
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _startWorkout(routine),
                icon: const Icon(
                  Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Inizia Questo Allenamento',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9700),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_rounded,
            color: Colors.white.withValues(alpha: 0.15),
            size: 64,
          ),
          const SizedBox(height: 14),
          const Text(
            'Nessuna scheda trovata',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedSplitFilter == 'Tutti'
                ? 'Non hai ancora programmato alcuna routine.\nPremi "+ Nuova" per creare la prima scheda.'
                : 'Nessuna scheda configurata per lo split "$_selectedSplitFilter".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- AZIONI E DIALOG ---
  void _openCreateRoutine({RoutineTemplate? routineToEdit}) async {
    if (widget.isar == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CreateRoutineScreen(
              isar: widget.isar!,
              existingRoutine: routineToEdit,
            ),
      ),
    );

    if (result == true) {
      _fetchRoutines(showSpinner: false);
    }
  }

  Future<void> _confirmDeleteRoutine(RoutineTemplate routine) async {
    final confirm = await AppDialog.show(
      context,
      type: AppDialogType.warning,
      title: 'Elimina Scheda',
      message:
          'Sei sicuro di voler eliminare definitivamente "${routine.name}"? L\'operazione non è reversibile.',
      primaryButtonText: 'Elimina',
      secondaryButtonText: 'Annulla',
    );

    if (confirm == true && widget.isar != null) {
      await widget.isar!.writeTxn(() async {
        await widget.isar!.routineTemplates.delete(routine.id);
      });

      if (!mounted) return;

      AppDialog.show(
        context,
        type: AppDialogType.info,
        title: 'Scheda Rimossa',
        message: 'La routine è stata eliminata dal database.',
        primaryButtonText: 'OK',
      );
    }
  }

  void _startWorkout(RoutineTemplate routine) {
    HapticFeedback.mediumImpact();
    AppDialog.show(
      context,
      type: AppDialogType.success,
      title: 'Pronto per la Sessione?',
      message:
          'Stai per avviare la scheda "${routine.name}". Verranno caricati automaticamente i target di serie e recupero impostati.',
      primaryButtonText: 'Inizia Ora',
      secondaryButtonText: 'Annulla',
      onPrimaryPressed: () {
        // Navigazione verso il motore d'allenamento
      },
    );
  }
}
