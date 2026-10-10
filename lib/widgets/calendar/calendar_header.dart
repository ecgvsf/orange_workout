import 'package:flutter/material.dart';

class CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const CalendarHeader({
    super.key,
    required this.focusedDay,
    required this.onPrevious,
    required this.onNext,
  });

  static const List<String> _monthNames = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  static const List<String> _weekdayNames = [
    'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Riga Anno, Mese e Frecce
        Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFFFF9700), size: 38),
                onPressed: onPrevious,
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${focusedDay.year}',
                        style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _monthNames[focusedDay.month - 1],
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF9700), size: 38),
                onPressed: onNext,
              ),
            ],
          ),
        ),

        // Pillola dei giorni della settimana
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          margin: const EdgeInsets.only(bottom: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF191919),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdayNames
                .map((day) => Text(day, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)))
                .toList(),
          ),
        ),
      ],
    );
  }
}