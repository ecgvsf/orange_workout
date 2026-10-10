import 'package:flutter/material.dart';

class CalendarTheme {
  // Palette dei 7 colori ad alto contrasto
  static const Color colorPetto = Color(0xFFD32F2F);
  static const Color colorDorso = Color(0xFFE64A19);
  static const Color colorSpalle = Color(0xFFFF9700);
  static const Color colorTricipiti = Color(0xFFFFC107);
  static const Color colorBicipiti = Color(0xFFFFEE58);
  static const Color colorGambe = Color(0xFFFFF9C4);
  static const Color colorCore = Color(0xFFFFFFFF);

  // Ordine di priorità cromatico fisso
  static const List<String> colorPriorityOrder = [
    'Petto',
    'Dorso',
    'Spalle',
    'Tricipiti',
    'Bicipiti',
    'Gambe',
    'Core',
  ];

  // Mappatura esaustiva alias -> Colore
  static const Map<String, Color> groupColors = {
    // PETTO
    'Petto': colorPetto,
    'Chest': colorPetto,
    'pectoralis_major': colorPetto,
    'serratus_anterior': colorPetto,
    'Serratus': colorPetto,

    // DORSO
    'Dorso': colorDorso,
    'Back': colorDorso,
    'Lats': colorDorso,
    'latissimus_dorsi': colorDorso,
    'Trapezio': colorDorso,
    'Trapezi': colorDorso,
    'Traps': colorDorso,
    'trapezius': colorDorso,
    'Alta Schiena': colorDorso,
    'rhomboids': colorDorso,
    'Rhomboids': colorDorso,
    'Lombari': colorDorso,
    'Lower Back': colorDorso,
    'erector_spinae': colorDorso,
    'quadratus_lumborum': colorDorso,
    'Quadratus Lumborum': colorDorso,

    // GAMBE
    'Gambe': colorGambe,
    'Legs': colorGambe,
    'Quadricipiti': colorGambe,
    'Quads': colorGambe,
    'quadriceps': colorGambe,
    'Femorali': colorGambe,
    'Hamstrings': colorGambe,
    'hamstrings': colorGambe,
    'Glutei': colorGambe,
    'Glutes': colorGambe,
    'gluteus_maximus': colorGambe,
    'gluteus_medius': colorGambe,
    'Glute Medius': colorGambe,
    'Abduttori': colorGambe,
    'abduttori': colorGambe,
    'Abductors': colorGambe,
    'abductors': colorGambe,
    'Adduttori': colorGambe,
    'adduttori': colorGambe,
    'Adductors': colorGambe,
    'adductors': colorGambe,
    'Polpacci': colorGambe,
    'Calves': colorGambe,
    'gastrocnemius': colorGambe,
    'Soleo': colorGambe,
    'soleo': colorGambe,
    'Soleus': colorGambe,
    'soleus': colorGambe,

    // SPALLE
    'Spalle': colorSpalle,
    'Shoulders': colorSpalle,
    'Deltoidi': colorSpalle,
    'deltoidi': colorSpalle,
    'Front Delts': colorSpalle,
    'anterior_deltoid': colorSpalle,
    'Side Delts': colorSpalle,
    'lateral_deltoid': colorSpalle,
    'Rear Delts': colorSpalle,
    'posterior_deltoid': colorSpalle,
    'supraspinatus': colorSpalle,
    'Supraspinatus': colorSpalle,

    // TRICIPITI
    'Tricipiti': colorTricipiti,
    'Triceps': colorTricipiti,
    'triceps_brachii': colorTricipiti,

    // BICIPITI
    'Bicipiti': colorBicipiti,
    'Biceps': colorBicipiti,
    'biceps_brachii': colorBicipiti,
    'brachialis': colorBicipiti,
    'Brachialis': colorBicipiti,
    'Avambracci': colorBicipiti,
    'Forearms': colorBicipiti,
    'forearms': colorBicipiti,
    'brachioradialis': colorBicipiti,
    'Brachioradialis': colorBicipiti,
    'forearm_flexors': colorBicipiti,
    'Forearm Flexors': colorBicipiti,
    'forearm_extensors': colorBicipiti,
    'Forearm Extensors': colorBicipiti,

    // CORE
    'Core': colorCore,
    'Addome': colorCore,
    'Addominali': colorCore,
    'Abs': colorCore,
    'rectus_abdominis': colorCore,
    'Obliqui': colorCore,
    'Obliques': colorCore,
    'obliques': colorCore,
    'transverse_abdominis': colorCore,
    'Deep Core': colorCore,
    'hip_flexors': colorCore,
    'Hip Flexors': colorCore,
  };

  /// Converte qualsiasi variante o sottomuscolo in uno dei 7 macro-gruppi base
  static String getNormalizedMacroGroup(String rawMuscle) {
    final lower = rawMuscle.toLowerCase().trim();

    if (lower.contains('petto') || lower.contains('chest') || lower.contains('serratus')) {
      return 'Petto';
    }
    if (lower.contains('dorso') || lower.contains('back') || lower.contains('lat') ||
        lower.contains('trapez') || lower.contains('rhomboid') || lower.contains('lombar') || lower.contains('erector')) {
      return 'Dorso';
    }
    if (lower.contains('quad') || lower.contains('femor') || lower.contains('hamstring') ||
        lower.contains('glut') || lower.contains('polpacc') || lower.contains('calv') ||
        lower.contains('sole') || lower.contains('addutt') || lower.contains('adductor') ||
        lower.contains('abdutt') || lower.contains('abductor') || lower.contains('gamb') || lower.contains('leg')) {
      return 'Gambe';
    }
    if (lower.contains('spall') || lower.contains('deltoid') || lower.contains('delt') || lower.contains('supraspinatus')) {
      return 'Spalle';
    }
    if (lower.contains('tricipit') || lower.contains('tricep')) {
      return 'Tricipiti';
    }
    if (lower.contains('bicipit') || lower.contains('bicep') || lower.contains('brachi') || lower.contains('avambracc') || lower.contains('forearm')) {
      return 'Bicipiti';
    }
    if (lower.contains('addom') || lower.contains('abs') || lower.contains('core') || lower.contains('obliq') || lower.contains('hip_flexor')) {
      return 'Core';
    }

    return rawMuscle;
  }

  static int getMusclePriority(String muscle) {
    final index = colorPriorityOrder.indexOf(muscle);
    if (index != -1) return index;

    final color = groupColors[muscle];
    if (color != null) {
      for (int i = 0; i < colorPriorityOrder.length; i++) {
        if (groupColors[colorPriorityOrder[i]] == color) return i;
      }
    }
    return 99;
  }
}