import 'package:flutter/material.dart';

/// I 4 Macro-Split operativi per il calcolo del volume e grafici aggregati
enum MacroSplit {
  push('Push (Spinta)', Color(0xFFFF9700)),
  pull('Pull (Tirata)', Color(0xFFFFB74D)),
  legs('Legs (Gambe)', Color(0xFFE65100)),
  core('Core & Tronco', Colors.white54);

  final String label;
  final Color color;
  const MacroSplit(this.label, this.color);
}

/// Enumeratore fortemente tipizzato dei gruppi muscolari principali
enum MuscleGroup {
  petto(
    label: 'Petto',
    macroSplit: MacroSplit.push,
    svgId: 'chest', // Combacia con <g id="chest"> nel tuo SVG
  ),
  dorso(
    label: 'Dorso',
    macroSplit: MacroSplit.pull,
    svgId: 'dorsali', // Combacia con <g id="dorsali">
  ),
  trapezio(
    label: 'Alta Schiena / Trapezio',
    macroSplit: MacroSplit.pull,
    svgId: 'trapezio', // Combacia con <g id="trapezio">
  ),
  lombari(
    label: 'Bassa Schiena',
    macroSplit: MacroSplit.pull,
    svgId: 'lombari', // Combacia con <g id="lombari">
  ),
  spalle(
    label: 'Spalle',
    macroSplit: MacroSplit.push,
    svgId: 'deltoidi', // Combacia con <g id="deltoidi"> e i suoi sotto-fasci
  ),
  bicipiti(
    label: 'Bicipiti',
    macroSplit: MacroSplit.pull,
    svgId: 'bicipiti', // Combacia con <g id="bicipiti">
  ),
  tricipiti(
    label: 'Tricipiti',
    macroSplit: MacroSplit.push,
    svgId: 'tricipiti', // Combacia con <g id="tricipiti">
  ),
  quadricipiti(
    label: 'Quadricipiti',
    macroSplit: MacroSplit.legs,
    svgId: 'quadricipiti', // Combacia con <g id="quadricipiti">
  ),
  femorali(
    label: 'Femorali',
    macroSplit: MacroSplit.legs,
    svgId: 'femorali', // O 'glutei' a seconda del distretto target
  ),
  glutei(
    label: 'Glutei',
    macroSplit: MacroSplit.legs,
    svgId: 'glutei', // Combacia con <g id="glutei">
  ),
  polpacci(
    label: 'Polpacci',
    macroSplit: MacroSplit.legs,
    svgId: 'polpacci', // Combacia con <g id="polpacci">
  ),
  addome(
    label: 'Addome',
    macroSplit: MacroSplit.core,
    svgId: 'addominali-centrali',
  ),
  obliqui(
    label: 'Obliqui',
    macroSplit: MacroSplit.core,
    svgId: 'addominali-laterali',
  ),
  adduttori(
    label: 'Adduttori',
    macroSplit: MacroSplit.legs,
    svgId: 'adduttori',
  ),
  abduttori(
    label: 'Abduttori',
    macroSplit: MacroSplit.legs,
    svgId: 'abduttori',
  ),
  soleo(
    label: 'Soleo',
    macroSplit: MacroSplit.legs,
    svgId: 'soleo',
  );


  final String label;
  final MacroSplit macroSplit;
  final String svgId;

  const MuscleGroup({
    required this.label,
    required this.macroSplit,
    required this.svgId,
  });

  /// Metodo factory per convertire una stringa salvata su DB nell'enum corretto
  static MuscleGroup fromString(String? value) {
    if (value == null) return MuscleGroup.petto;
    return MuscleGroup.values.firstWhere(
      (m) =>
          m.name.toLowerCase() == value.toLowerCase() ||
          m.label.toLowerCase() == value.toLowerCase(),
      orElse: () => MuscleGroup.petto,
    );
  }
}
