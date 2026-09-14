import 'package:isar/isar.dart';
import '../models/exercise.dart';
import 'muscle_group.dart';

Future<void> seedInitialExercises(Isar isar) async {
  // Controlla se il catalogo esercizi è già popolato nel DB
  final int count = await isar.exercises.count();
  if (count > 0) return; // Se ci sono già dati, non duplica nulla

  final defaultExercises = [
    // ==========================================
    // PUSH (Spinta: Petto, Spalle, Tricipiti)
    // ==========================================
    Exercise()
      ..name = 'Panca Piana Bilanciere'
      ..muscleGroup = MuscleGroup.petto.label
      ..secondaryMuscles = [
        MuscleGroup.spalle.label, // Deltoide anteriore
        MuscleGroup.tricipiti.label, // Estensore del gomito
      ]
      ..isCompound = true
      ..equipment = 'Bilanciere',

    Exercise()
      ..name = 'Chest Press'
      ..muscleGroup = MuscleGroup.petto.label
      ..secondaryMuscles = [
        MuscleGroup.spalle.label,
        MuscleGroup.tricipiti.label,
      ]
      ..isCompound = true
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Chest Press Wide'
      ..muscleGroup = MuscleGroup.petto.label
      ..secondaryMuscles = [
        MuscleGroup.spalle.label,
        MuscleGroup.tricipiti.label,
      ]
      ..isCompound = true
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Spinte Manubri Inclinata'
      ..muscleGroup = MuscleGroup.petto.label
      ..secondaryMuscles = [
        MuscleGroup.spalle.label, // Forte attivazione fascio clavicolare
        MuscleGroup.tricipiti.label,
      ]
      ..isCompound =
          true // Movimento biarticolare (spalla + gomito)
      ..equipment = 'Manubri',

    Exercise()
      ..name = 'Seated Dips'
      ..muscleGroup = MuscleGroup.tricipiti.label
      ..secondaryMuscles = [
        MuscleGroup.petto.label, // Gran pettorale fascio basso
        MuscleGroup.spalle.label, // Deltoide anteriore
      ]
      ..isCompound = true
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Croci ai Cavi'
      ..muscleGroup = MuscleGroup.petto.label
      ..secondaryMuscles =
          [] // Puro isolamento sternocostale
      ..isCompound = false
      ..equipment = 'Cavi',

    Exercise()
      ..name = 'Military Press Bilanciere'
      ..muscleGroup = MuscleGroup.spalle.label
      ..secondaryMuscles = [
        MuscleGroup.tricipiti.label, // Estensione gomito lockout
        MuscleGroup.trapezi.label, // Trapezi e stabilizzatori
      ]
      ..isCompound = true
      ..equipment = 'Bilanciere',

    Exercise()
      ..name = 'Shoulder Press'
      ..muscleGroup = MuscleGroup.spalle.label
      ..secondaryMuscles = [MuscleGroup.tricipiti.label]
      ..isCompound =
          true // Spinta verticale biarticolare
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Alzate Laterali Manubri'
      ..muscleGroup = MuscleGroup.spalle.label
      ..secondaryMuscles =
          [] // Isolamento deltoide laterale
      ..isCompound = false
      ..equipment = 'Manubri',

    Exercise()
      ..name = 'Pushdown Cavo'
      ..muscleGroup = MuscleGroup.tricipiti.label
      ..secondaryMuscles =
          [] // Monoarticolare (estensione pura del gomito)
      ..isCompound = false
      ..equipment = 'Cavi',

    // ==========================================
    // PULL (Tirata: Dorso, Trapezi, Bicipiti)
    // ==========================================
    Exercise()
      ..name = 'Trazioni alla Sbarra'
      ..muscleGroup = MuscleGroup.dorso.label
      ..secondaryMuscles = [
        MuscleGroup.bicipiti.label, // Flessori del gomito
        MuscleGroup.trapezi.label, // Romboidi e trapezi medi/bassi
      ]
      ..isCompound = true
      ..equipment = 'Corpo Libero',

    Exercise()
      ..name = 'Rematore'
      ..muscleGroup = MuscleGroup.dorso.label
      ..secondaryMuscles = [
        MuscleGroup.bicipiti.label,
        MuscleGroup.trapezi.label,
        MuscleGroup.lombari.label, // Stabilizzazione isometrica
      ]
      ..isCompound = true
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Lat Machine Avanti'
      ..muscleGroup = MuscleGroup.dorso.label
      ..secondaryMuscles = [
        MuscleGroup.bicipiti.label,
        MuscleGroup.trapezi.label,
      ]
      ..isCompound =
          true // Biarticolare (adduzione spalla + flessione gomito)
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Pulley Basso'
      ..muscleGroup = MuscleGroup.trapezi.label
      ..secondaryMuscles = [MuscleGroup.dorso.label, MuscleGroup.bicipiti.label]
      ..isCompound =
          true // Spessore dorso con retrazione scapolare
      ..equipment = 'Cavi',

    Exercise()
      ..name = 'Face Pull ai Cavi'
      ..muscleGroup = MuscleGroup.trapezi.label
      ..secondaryMuscles = [
        MuscleGroup.spalle.label, // Deltoide posteriore ed extrarotatori
      ]
      ..isCompound = false
      ..equipment = 'Cavi',

    Exercise()
      ..name = 'Scott Curl'
      ..muscleGroup = MuscleGroup.bicipiti.label
      ..secondaryMuscles =
          [] // Isolamento flessori su panca Scott
      ..isCompound = false
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Hammer Curl con Manubri'
      ..muscleGroup = MuscleGroup.bicipiti.label
      ..secondaryMuscles =
          [] // Brachioradiale e bicipite brachiale
      ..isCompound = false
      ..equipment = 'Manubri',

    // ==========================================
    // LEGS (Gambe: Quadricipiti, Catena Posteriore, Polpacci)
    // ==========================================
    Exercise()
      ..name = 'Squat con Bilanciere'
      ..muscleGroup = MuscleGroup.quadricipiti.label
      ..secondaryMuscles = [
        MuscleGroup.glutei.label, // Grande gluteo estensore dell'anca
        MuscleGroup.femorali.label,
        MuscleGroup.lombari.label,
      ]
      ..isCompound = true
      ..equipment = 'Bilanciere',

    Exercise()
      ..name = 'Leg Press 45°'
      ..muscleGroup = MuscleGroup.quadricipiti.label
      ..secondaryMuscles = [MuscleGroup.glutei.label]
      ..isCompound = true
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Leg Extension'
      ..muscleGroup = MuscleGroup.quadricipiti.label
      ..secondaryMuscles =
          [] // Isolamento puro quadricipite
      ..isCompound = false
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Deadlift'
      ..muscleGroup = MuscleGroup.femorali.label
      ..secondaryMuscles = [
        MuscleGroup.glutei.label, // Motore primario di estensione dell'anca
        MuscleGroup.lombari.label, // Erettori spinali
        MuscleGroup.trapezi.label, // Trapezi e romboidi isometrici
        MuscleGroup.quadricipiti.label, // Spinta iniziale a terra
      ]
      ..isCompound = true
      ..equipment = 'Bilanciere',

    Exercise()
      ..name = 'Leg Curl Seduto'
      ..muscleGroup = MuscleGroup.femorali.label
      ..secondaryMuscles =
          [] // Isolamento flessori del ginocchio
      ..isCompound = false
      ..equipment = 'Macchinario',

    Exercise()
      ..name = 'Calf Machine in Piedi'
      ..muscleGroup = MuscleGroup.polpacci.label
      ..secondaryMuscles =
          [] // Isolamento gastrocnemio
      ..isCompound = false
      ..equipment = 'Macchinario',

    // ==========================================
    // CORE (Tronco e Addome)
    // ==========================================
    Exercise()
      ..name = 'Plank a Terra'
      ..muscleGroup = MuscleGroup.addome.label
      ..secondaryMuscles = [
        MuscleGroup.spalle.label, // Tenuta isometrica
      ]
      ..isCompound = false
      ..equipment = 'Corpo Libero',

    Exercise()
      ..name = 'Crunch al Cavo'
      ..muscleGroup = MuscleGroup.addome.label
      ..secondaryMuscles =
          [] // Flessione pura della colonna
      ..isCompound = false
      ..equipment = 'Cavi',
  ];

  // Scrittura batch su Isar
  await isar.writeTxn(() async {
    await isar.exercises.putAll(defaultExercises);
  });
}
