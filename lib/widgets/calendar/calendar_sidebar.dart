import 'package:flutter/material.dart';
import '../../models/calendar_models.dart';
import 'vertical_muscle_bar.dart';

class CalendarSidebar extends StatelessWidget {
  final DateTime selectedDay;
  final bool isSelectionMode;
  final int selectedCount;
  final List<ExerciseDetail> currentExercises;
  final String? selectedMuscleGroup;
  final GlobalKey cardStackKey;
  final VoidCallback onJumpToToday;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onDeleteSelected;
  final OnBarSegmentSelected onBarSegmentSelected;

  const CalendarSidebar({
    super.key,
    required this.selectedDay,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.currentExercises,
    required this.selectedMuscleGroup,
    required this.cardStackKey,
    required this.onJumpToToday,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
    required this.onBarSegmentSelected,
  });

  static const List<String> _weekdayNames = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool isSelectedToday = _isSameDay(selectedDay, now);
    final dayNum = '${selectedDay.day}';
    final weekday = _weekdayNames[selectedDay.weekday - 1];

    return Container(
      width: 76,
      padding: const EdgeInsets.only(top: 8.0, bottom: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Blocco data con tap per "Oggi"
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onJumpToToday,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayNum,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.1),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekday,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelectedToday ? Colors.white : Colors.white60,
                        fontSize: 13,
                        fontWeight: isSelectedToday ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (isSelectedToday) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: Color(0xFFFF9700), shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tasto Selezione
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: isSelectionMode ? 'Annulla selezione' : 'Seleziona esercizi',
            icon: Icon(
              Icons.pan_tool_alt_rounded,
              color: isSelectionMode ? Colors.white : const Color(0xFFFF9700),
              size: 26,
            ),
            onPressed: currentExercises.isEmpty ? null : onToggleSelectionMode,
          ),

          // Tasto Elimina animato
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            child: isSelectionMode
                ? Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: selectedCount > 0 ? 'Elimina ($selectedCount)' : 'Seleziona almeno un esercizio',
                icon: Icon(
                  Icons.delete_rounded,
                  color: selectedCount > 0 ? Colors.redAccent : Colors.white24,
                  size: 26,
                ),
                onPressed: selectedCount > 0 ? onDeleteSelected : null,
              ),
            )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Barra verticale muscolare
          Expanded(
            child: VerticalMuscleBar(
              exercises: currentExercises,
              selectedGroup: selectedMuscleGroup,
              cardStackKey: cardStackKey,
              onSegmentSelected: onBarSegmentSelected,
            ),
          ),
        ],
      ),
    );
  }
}