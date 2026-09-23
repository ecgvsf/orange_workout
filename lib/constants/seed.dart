import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:isar/isar.dart';

import '../models/exercise.dart';
import '../models/exercise_type.dart';

/// Funzione di seeding iniziale che popola Isar al primo avvio
Future<void> seedInitialExercises(Isar isar) async {
  // Evita duplicazioni se il database contiene già degli esercizi
  final int count = await isar.exercises.count();
  if (count > 0) return;

  try {
    // 1. Carica il file JSON dal bundle degli asset
    final String jsonContent = await rootBundle.loadString(
      'assets/data/free.en.json',
    );
    final Map<String, dynamic> decoded = json.decode(jsonContent);

    final List<dynamic> rawList = decoded['exercises'] ?? [];
    if (rawList.isEmpty) return;

    // 2. Mappatura dei muscoli RepDB verso le etichette usate nella tua app e nell'SVG
    //    Queste label corrispondono agli svgId della sagoma:
    //    'chest', 'dorsali', 'deltoidi', 'bicipiti', 'tricipiti',
    //    'addominali', 'quadricipiti', 'femorali', 'glutei', 'polpacci', 'lombari', 'trapezio'
    final Map<String, String> muscleMapping = {
      // Petto
      'pectoralis_major': 'Petto',
      'serratus_anterior': 'Petto',

      // Spalle
      'anterior_deltoid': 'Spalle',
      'lateral_deltoid': 'Spalle',
      'posterior_deltoid': 'Spalle',
      'supraspinatus': 'Spalle',

      // Braccia
      'biceps_brachii': 'Bicipiti',
      'brachialis': 'Bicipiti',
      'brachioradialis': 'Avambracci',
      'triceps_brachii': 'Tricipiti',
      'forearms': 'Avambracci',
      'forearm_flexors': 'Avambracci',
      'forearm_extensors': 'Avambracci',

      // Schiena e Trapezi
      'latissimus_dorsi': 'Dorso',
      'rhomboids': 'Trapezio',
      'trapezius': 'Trapezio',
      'erector_spinae': 'Lombari',
      'quadratus_lumborum': 'Lombari',

      // Core / Addome
      'rectus_abdominis': 'Addome', // Centrali
      'transverse_abdominis': 'Addome', // Centrali profondi
      'hip_flexors': 'Addome', // Flessori
      'obliques': 'Obliqui', // Laterali
      // Gambe
      'quadriceps': 'Quadricipiti',
      'hamstrings': 'Femorali',
      'gluteus_maximus': 'Glutei',
      'gluteus_medius': 'Glutei',
      'abductors': 'abduttori',
      'adductors': 'adduttori',
      'gastrocnemius': 'Polpacci',
      'soleus': 'soleo',
    };

    final Map<String, String> bodyPartFallback = {
      'chest': 'Petto',
      'shoulders': 'Spalle',
      'upper_arms': 'Braccia',
      'lower_arms': 'Avambracci',
      'back': 'Dorso',
      'core': 'Addome',
      'upper_legs': 'Gambe',
      'lower_legs': 'Polpacci',
      'full_body': 'Corpo Libero',
    };

    // 3. Mappatura attrezzi per renderli leggibili nella UI
    final Map<String, String> equipmentMapping = {
      'barbell': 'Bilanciere',
      'dumbbell': 'Manubri',
      'kettlebell': 'Kettlebell',
      'cable': 'Cavi',
      'machine': 'Macchinario',
      'chest_press_machine': 'Macchinario',
      'lat_pulldown_machine': 'Macchinario',
      'leg_press': 'Macchinario',
      'leg_extension': 'Macchinario',
      'leg_curl': 'Macchinario',
      'smith_machine': 'Multipower',
      'pull_up_bar': 'Corpo Libero',
      'dip_station': 'Corpo Libero',
      'bodyweight_aid': 'Corpo Libero',
      'resistance_band': 'Elastici',
      'loop_band': 'Elastici',
    };

    final List<Exercise> exercisesToInsert = [];

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) continue;

      final String id = item['id'] ?? '';

      // Nome esercizio (privilegia la traduzione se disponibile, altrimenti nome in inglese)
      final String name =
          item['name_it'] ??
          item['name_it_it'] ??
          item['name'] ??
          item['name_en'] ??
          id.replaceAll('-', ' ');

      // Estrazione campi dal JSON
      final String forceType = item['force_type'] ?? '';
      final String category = item['category'] ?? '';
      final List<dynamic> tags = item['tags'] ?? [];

      // Logica deterministica per gli esercizi a tempo
      final bool isTimeBased =
          forceType == 'static' ||
          category == 'cardio' ||
          category == 'stretching' ||
          tags.contains('conditioning');

      // Calcola gruppo muscolare primario
      final List<dynamic> primaryMusclesRaw = item['primary_muscles'] ?? [];
      String primaryGroup = 'Generale';

      if (primaryMusclesRaw.isNotEmpty) {
        final firstMuscle = primaryMusclesRaw.first.toString();
        primaryGroup =
            muscleMapping[firstMuscle] ??
            bodyPartFallback[item['body_part']?.toString() ?? ''] ??
            'Generale';
      } else if (item['body_part'] != null) {
        primaryGroup = bodyPartFallback[item['body_part']] ?? 'Generale';
      }

      // Calcola i gruppi muscolari secondari sinergici
      final List<dynamic> secondaryMusclesRaw = item['secondary_muscles'] ?? [];
      final Set<String> secondaryGroups = {};

      for (final sec in secondaryMusclesRaw) {
        final mapped = muscleMapping[sec.toString()];
        if (mapped != null && mapped != primaryGroup) {
          secondaryGroups.add(mapped);
        }
      }

      // Meccanica: Multiarticolare vs Isolamento
      final bool isCompound = item['mechanic'] == 'compound';

      // Attrezzo utilizzato
      final String rawEquipment = item['equipment']?.toString() ?? '';
      final String? cleanEquipment =
          equipmentMapping[rawEquipment] ??
          (rawEquipment.isNotEmpty
              ? rawEquipment.replaceAll('_', ' ').toUpperCase()
              : null);

      // Risoluzione immagine: verifica se è presente la variante start, main o il nome diretto dell'id
      // Risoluzione flessibile del path immagine per RepDB
      String? imagePath;
      final imagesObj = item['images'];

      if (imagesObj is Map && imagesObj['flat'] is List) {
        final List flatList = imagesObj['flat'];
        if (flatList.isNotEmpty) {
          // Es. se il JSON indica 'start', cercherà 'id-start.webp'
          final String frame = flatList.first.toString().replaceAll('_', '-');
          imagePath = 'assets/images/flat/$id-$frame.webp';
        }
      }

      // Fallback se non specificato: prova '-start', poi '-main', altrimenti '$id.webp'
      imagePath ??= 'assets/images/flat/$id-start.webp';

      final exercise =
          Exercise()
            ..name = name.trim()
            ..muscleGroup = primaryGroup
            ..secondaryMuscles = secondaryGroups.toList()
            ..isCompound = isCompound
            ..equipment = cleanEquipment
            ..exerciseType = isTimeBased ? ExerciseType.time : ExerciseType.reps
            ..imagePath = imagePath;

      exercisesToInsert.add(exercise);
    }

    // 4. Inserimento batch ad alta velocità in un'unica transazione Isar
    await isar.writeTxn(() async {
      await isar.exercises.putAll(exercisesToInsert);
    });

    debugPrint(
      'Seeding completato con successo: ${exercisesToInsert.length} esercizi importati.',
    );
  } catch (e, stack) {
    debugPrint('Errore durante il parsing/seeding di free.json: $e');
    debugPrint(stack.toString());
  }
}
