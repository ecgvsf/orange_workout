import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

// Modello dettagliato per il singolo esercizio
class ExerciseDetail {
  final String name;
  final String imageUrl;
  final int sets;
  final int avgReps;
  final double avgWeight;

  const ExerciseDetail({
    required this.name,
    required this.imageUrl,
    required this.sets,
    required this.avgReps,
    required this.avgWeight,
  });
}

class CalendarWorkoutSummary {
  final String title;
  final List<ExerciseDetail> exercises;

  const CalendarWorkoutSummary({required this.title, required this.exercises});
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final ScrollController _scrollController = ScrollController();
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  late final Map<DateTime, int> _workoutDots;
  late final Map<DateTime, List<CalendarWorkoutSummary>> _workoutEvents;

  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _weekdayNames = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);

    // Controller per l'animazione di espansione/riduzione della card
    // Controller per l'animazione di espansione/riduzione della card
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve:
          Curves
              .easeInOutCubicEmphasized, // <-- Curva più morbida e progressiva
    );

    // Mock dei pallini del mese
    _workoutDots = {
      DateTime(now.year, now.month, 9): 4,
      DateTime(now.year, now.month, 10): 4,
      DateTime(now.year, now.month, 13): 4,
      DateTime(now.year, now.month, 14): 4,
      DateTime(now.year, now.month, 16): 4,
      DateTime(now.year, now.month, 20): 4,
      DateTime(now.year, now.month, 21): 4,
      DateTime(now.year, now.month, 23): 3,
      DateTime(now.year, now.month, 24): 2,
      DateTime(now.year, now.month, 28): 3,
    };

    // Dati mock con gli esercizi come mostrati nello screenshot di riferimento
    _workoutEvents = {
      DateTime(now.year, now.month, now.day): [
        const CalendarWorkoutSummary(
          title: 'Full Body A',
          exercises: [
            ExerciseDetail(
              name: 'Plank',
              imageUrl:
                  'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=300&q=80',
              sets: 1,
              avgReps: 0,
              avgWeight: 0,
            ),

            ExerciseDetail(
              name: 'Pull Down',
              imageUrl:
                  'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=300&q=80',
              sets: 2,
              avgReps: 30,
              avgWeight: 85,
            ),
            ExerciseDetail(
              name: 'Inclined Push up',
              imageUrl:
                  'https://images.unsplash.com/photo-1598971639058-fab3c3109a00?w=300&q=80',
              sets: 3,
              avgReps: 40,
              avgWeight: 0,
            ),
            ExerciseDetail(
              name: 'Medium Row Close Grip',
              imageUrl:
                  'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=300&q=80',
              sets: 3,
              avgReps: 20,
              avgWeight: 65,
            ),
            ExerciseDetail(
              name: 'Biceps Curls One Arm',
              imageUrl:
                  'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=300&q=80',
              sets: 2,
              avgReps: 30,
              avgWeight: 30,
            ),
          ],
        ),
      ],
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  List<CalendarWorkoutSummary> _getEventsForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _workoutEvents[normalized] ?? [];
  }

  int _getDotsCount(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _workoutDots[normalized] ??
        (_workoutEvents[normalized] != null ? 3 : 0);
  }

  void _toggleFormat([CalendarFormat? targetFormat]) {
    setState(() {
      if (targetFormat != null) {
        _calendarFormat = targetFormat;
      } else {
        _calendarFormat =
            _calendarFormat == CalendarFormat.month
                ? CalendarFormat.week
                : CalendarFormat.month;
      }
    });

    if (_calendarFormat == CalendarFormat.week) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _goToPrevious() {
    setState(() {
      if (_calendarFormat == CalendarFormat.week) {
        _focusedDay = _focusedDay.subtract(const Duration(days: 7));
      } else {
        _focusedDay = DateTime(
          _focusedDay.year,
          _focusedDay.month - 1,
          _focusedDay.day.clamp(1, 28),
        );
      }
    });
  }

  void _goToNext() {
    setState(() {
      if (_calendarFormat == CalendarFormat.week) {
        _focusedDay = _focusedDay.add(const Duration(days: 7));
      } else {
        _focusedDay = DateTime(
          _focusedDay.year,
          _focusedDay.month + 1,
          _focusedDay.day.clamp(1, 28),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double cutOffBottom = bottomInset - 20;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- 1. CALENDARIO IN ALTO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFFFF9700),
                            size: 38,
                          ),
                          onPressed: _goToPrevious,
                        ),
                        Column(
                          children: [
                            Text(
                              '${_focusedDay.year}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _monthNames[_focusedDay.month - 1],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFFF9700),
                            size: 38,
                          ),
                          onPressed: _goToNext,
                        ),
                      ],
                    ),
                  ),

                  // Header giorni della settimana pillola
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF191919),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'Mon',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Tue',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Wed',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Thu',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Fri',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Sat',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Sun',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Griglia Giorni
                  TableCalendar<CalendarWorkoutSummary>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    formatAnimationDuration: const Duration(
                      milliseconds: 850,
                    ), // <-- Stessa durata della card
                    formatAnimationCurve: Curves.easeInOutCubicEmphasized,
                    pageAnimationDuration: const Duration(milliseconds: 260),
                    pageAnimationCurve: Curves.easeInOutCubicEmphasized,
                    pageJumpingEnabled: false,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerVisible: false,
                    daysOfWeekVisible: false,
                    rowHeight: 60.0,
                    daysOfWeekHeight: 0,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        return _buildSquareCell(
                          day: day,
                          textColor: Colors.white,
                          borderColor: const Color(0xFF242424),
                          backgroundColor: Colors.transparent,
                          dotsCount: _getDotsCount(day),
                        );
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        final bool isCurrentDay = isSameDay(
                          day,
                          DateTime.now(),
                        );
                        return _buildSquareCell(
                          day: day,
                          textColor: Colors.white,
                          borderColor: const Color(0xFFFF9700),
                          borderWidth: 1.8,
                          backgroundColor:
                              isCurrentDay
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.transparent,
                          dotsCount: _getDotsCount(day),
                        );
                      },
                      todayBuilder: (context, day, focusedDay) {
                        return _buildSquareCell(
                          day: day,
                          textColor: Colors.white,
                          borderColor: const Color(
                            0xFFFF9700,
                          ).withValues(alpha: 0.5),
                          borderWidth: 1.4,
                          backgroundColor: const Color(
                            0xFF2C2C2E,
                          ), // Sfondo grigio distintivo
                          dotsCount: _getDotsCount(day),
                        );
                      },
                      outsideBuilder: (context, day, focusedDay) {
                        return Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Color(0xFF424242),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // --- 2. CARD INFERIORE ADATTIVA CON ANIMAZIONE ---
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: cutOffBottom,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF232325),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                      bottom: Radius.circular(0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                      bottom: Radius.circular(0),
                    ),
                    child: Column(
                      children: [
                        // Maniglietta Drag
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            if (details.primaryDelta != null) {
                              if (details.primaryDelta! < -4 &&
                                  _calendarFormat == CalendarFormat.month) {
                                _toggleFormat(CalendarFormat.week);
                              } else if (details.primaryDelta! > 4 &&
                                  _calendarFormat == CalendarFormat.week) {
                                _toggleFormat(CalendarFormat.month);
                              }
                            }
                          },
                          onTap: () => _toggleFormat(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(
                              top: 12.0,
                              bottom: 8.0,
                            ),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9700),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Corpo della Card: Colonna fissa Sinistra + Lista Esercizi Animata Destra
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Colonna laterale sinistra con Data e Icone
                              _buildLeftSidebar(),

                              // Linea verticale divisoria
                              Container(
                                width: 1.5,
                                margin: const EdgeInsets.only(
                                  top: 4.0,
                                  bottom: 20.0,
                                ),
                                color: Colors.white24,
                              ),

                              // 2. Lista Esercizi con transizione animata
                              Expanded(
                                child:
                                    selectedEvents.isEmpty
                                        ? _buildEmptyState()
                                        : ListView.builder(
                                          controller: _scrollController,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(
                                            16.0,
                                            4.0,
                                            16.0,
                                            80.0,
                                          ),
                                          itemCount:
                                              selectedEvents
                                                  .first
                                                  .exercises
                                                  .length,
                                          itemBuilder: (context, index) {
                                            final exercise =
                                                selectedEvents
                                                    .first
                                                    .exercises[index];
                                            return _buildAnimatedExerciseItem(
                                              exercise,
                                            );
                                          },
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Colonna di sinistra perfettamente centrata
  Widget _buildLeftSidebar() {
    final currentDay = _selectedDay ?? DateTime.now();
    final dayNum = '${currentDay.day}';
    final weekday = _weekdayNames[currentDay.weekday - 1];

    return Container(
      width: 76,
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Centratura orizzontale
        children: [
          Text(
            dayNum,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          Text(
            weekday,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),

          // Icone arancioni perfettamente centrate
          const Center(
            child: Icon(
              Icons.build_rounded,
              color: Color(0xFFFF9700),
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Icon(
              Icons.pan_tool_alt_rounded,
              color: Color(0xFFFF9700),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Elemento della lista con linea orizzontale allungata
  Widget _buildAnimatedExerciseItem(ExerciseDetail exercise) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final t =
            _expandAnimation
                .value; // 0.0 = mensile/compatto, 1.0 = settimanale/espanso

        final double imageSize = 44.0 + (32.0 * t); // Da 44px a 76px
        final double imageRadius = 14.0 + (6.0 * t);
        final double itemMarginBottom = 16.0 + (4.0 * t);

        return Container(
          margin: EdgeInsets.only(bottom: itemMarginBottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Immagine dell'esercizio con angoli arrotondati
              ClipRRect(
                borderRadius: BorderRadius.circular(imageRadius),
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  color: const Color(0xFF333333),
                  child: Image.network(
                    exercise.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.white38,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Testi, linea arancione e dettagli
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Quando t < 0.15: Linea orizzontale lunga che riempie lo spazio a destra
                    if (t < 0.15)
                      Container(
                        height: 2.0,
                        width:
                            double
                                .infinity, // Riempie tutta la larghezza disponibile a destra
                        margin: const EdgeInsets.only(top: 4.0, right: 75.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9700),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    // Quando espanso: Linea verticale a sinistra dei dettagli
                    else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 2.0,
                              margin: const EdgeInsets.only(
                                right: 8.0,
                                top: 2.0,
                                bottom: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFF9700,
                                ).withValues(alpha: t.clamp(0.0, 1.0)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Series tot: ${exercise.sets}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Average reps: ${exercise.avgReps}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Average weight: ${exercise.avgWeight.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nessun allenamento',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareCell({
    required DateTime day,
    required Color textColor,
    required Color borderColor,
    required Color backgroundColor,
    double borderWidth = 1.0,
    required int dotsCount,
  }) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        margin: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (dotsCount > 0) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  dotsCount > 4 ? 4 : dotsCount,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    width: 4.5,
                    height: 4.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9700),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
