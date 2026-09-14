import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/routine_template.dart';
import '../models/exercise.dart';

class RoutinesScreen extends StatefulWidget {
  final Isar? isar;

  const RoutinesScreen({super.key, this.isar});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  // Struttura dati locale (mock/fallback se Isar non ha ancora dati salvati)
  List<Map<String, dynamic>> _routines = [
    {
      'id': 1,
      'name': 'Push A (Spinta & Petto Focus)',
      'notes': 'Focus su panca piana e progressione di carico sui tricipiti.',
      'exercises': [
        {
          'name': 'Panca Piana Bilanciere',
          'sets': 4,
          'reps': '6-8',
          'muscle': 'Chest',
        },
        {
          'name': 'Spinte Manubri Inclinata',
          'sets': 3,
          'reps': '8-10',
          'muscle': 'Chest',
        },
        {
          'name': 'Military Press',
          'sets': 3,
          'reps': '8',
          'muscle': 'Shoulders',
        },
        {'name': 'Dip Parallele', 'sets': 3, 'reps': '10', 'muscle': 'Chest'},
        {
          'name': 'French Press Bilanciere EZ',
          'sets': 4,
          'reps': '10-12',
          'muscle': 'Triceps',
        },
        {
          'name': 'Alzate Laterali ai Cavi',
          'sets': 4,
          'reps': '12-15',
          'muscle': 'Shoulders',
        },
      ],
    },
    {
      'id': 2,
      'name': 'Pull A (Tirata & Dorso Focus)',
      'notes': 'Focus ampiezza dorsale e spessore romboidi.',
      'exercises': [
        {
          'name': 'Trazioni alla Sbarra Zavorrate',
          'sets': 4,
          'reps': '6',
          'muscle': 'Back',
        },
        {
          'name': 'Rematore con Bilanciere',
          'sets': 4,
          'reps': '8',
          'muscle': 'Back',
        },
        {
          'name': 'Pulley Basso al Cavo',
          'sets': 3,
          'reps': '10',
          'muscle': 'Back',
        },
        {'name': 'Face Pull', 'sets': 3, 'reps': '15', 'muscle': 'Rear Delts'},
        {
          'name': 'Curl con Bilanciere Sagomato',
          'sets': 4,
          'reps': '8-10',
          'muscle': 'Biceps',
        },
        {
          'name': 'Hammer Curl con Manubri',
          'sets': 3,
          'reps': '12',
          'muscle': 'Biceps',
        },
      ],
    },
    {
      'id': 3,
      'name': 'Legs & Core (Quad Focus)',
      'notes': 'RPE 8.5 sui fondamentali, cura il ROM profondo.',
      'exercises': [
        {
          'name': 'Squat con Bilanciere',
          'sets': 4,
          'reps': '6',
          'muscle': 'Legs',
        },
        {'name': 'Leg Press 45°', 'sets': 3, 'reps': '10', 'muscle': 'Legs'},
        {'name': 'Leg Extension', 'sets': 3, 'reps': '12', 'muscle': 'Legs'},
        {
          'name': 'Leg Curl da Seduto',
          'sets': 4,
          'reps': '10',
          'muscle': 'Hamstrings',
        },
        {
          'name': 'Calf Raise in Piedi',
          'sets': 4,
          'reps': '15',
          'muscle': 'Calves',
        },
        {'name': 'Plank Zavorrato', 'sets': 3, 'reps': '60s', 'muscle': 'Core'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Spazio per non coprire le ultime card con la floating bottom navigation bar
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double cutOffBottom = bottomInset + 95.0;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // --- HEADER PRINCIPALE ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Schede & Routine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_routines.length} schede attive nel mesociclo',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // Tasto aggiungi nuova scheda
                  ElevatedButton.icon(
                    onPressed: () => _openRoutineEditor(),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                    label: const Text(
                      'Nuova',
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

              const SizedBox(height: 12),
              const Divider(color: Color(0xFFFF9700), thickness: 1, height: 1),
              const SizedBox(height: 14),

              // --- LISTA SCHEDE ---
              Expanded(
                child:
                    _routines.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: cutOffBottom),
                          itemCount: _routines.length,
                          itemBuilder: (context, index) {
                            final routine = _routines[index];
                            return _buildRoutineCard(routine, index);
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET SCHEDA SINGOLA ---
  Widget _buildRoutineCard(Map<String, dynamic> routine, int index) {
    final List<Map<String, dynamic>> exercises =
        (routine['exercises'] as List).cast<Map<String, dynamic>>();

    int totalSets = exercises.fold<int>(
      0,
      (sum, item) => sum + (item['sets'] as int? ?? 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: index == 0,
          iconColor: const Color(0xFFFF9700),
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          title: Text(
            routine['name'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                _buildBadge(
                  '${exercises.length} esercizi',
                  const Color(0xFF2C2C2E),
                  Colors.white70,
                ),
                const SizedBox(width: 8),
                _buildBadge(
                  '$totalSets set tot.',
                  const Color(0xFFFF9700).withValues(alpha: 0.15),
                  const Color(0xFFFF9700),
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            color: const Color(0xFF252528),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onSelected: (value) {
              if (value == 'edit') {
                _openRoutineEditor(existingRoutine: routine, index: index);
              } else if (value == 'delete') {
                _deleteRoutine(index);
              } else if (value == 'start') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Avvio sessione: ${routine['name']}'),
                    backgroundColor: const Color(0xFFFF9700),
                  ),
                );
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
                          'Inizia Allenamento',
                          style: TextStyle(color: Colors.white),
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
            if (routine['notes'] != null &&
                (routine['notes'] as String).isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  routine['notes'],
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Lista degli esercizi inclusi nella scheda
            ...exercises.map((exercise) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
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
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            exercise['muscle'],
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
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${exercise['sets']} × ${exercise['reps']}',
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            // Tasto rapido Avvia Allenamento in fondo alla card aperta
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Avvio sessione: ${routine['name']}'),
                      backgroundColor: const Color(0xFFFF9700),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFFFF9700),
                  size: 18,
                ),
                label: const Text(
                  'Inizia Questo Allenamento',
                  style: TextStyle(
                    color: Color(0xFFFF9700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF9700), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
          const SizedBox(height: 12),
          const Text(
            'Nessuna scheda creata',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crea la tua prima routine per pianificare gli split.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _deleteRoutine(int index) {
    setState(() {
      _routines.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scheda eliminata'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // --- MODALE DI CREAZIONE / MODIFICA SCHEDA ---
  void _openRoutineEditor({Map<String, dynamic>? existingRoutine, int? index}) {
    final TextEditingController nameController = TextEditingController(
      text: existingRoutine?['name'] ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: existingRoutine?['notes'] ?? '',
    );

    List<Map<String, dynamic>> tempExercises =
        existingRoutine != null
            ? List<Map<String, dynamic>>.from(
              (existingRoutine['exercises'] as List).map(
                (e) => Map<String, dynamic>.from(e),
              ),
            )
            : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 18,
                right: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Maniglia superiore
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
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingRoutine == null
                            ? 'Nuova Scheda'
                            : 'Modifica Scheda',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nome Scheda
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nome Scheda (es. Push Day, Upper A)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF141414),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Note Coach
                  TextField(
                    controller: notesController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Note o Focus del Mesociclo (Opzionale)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF141414),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sezione Esercizi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Esercizi Inclusi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // Dialog aggiunta rapida esercizio
                          _showAddExercisePicker(
                            onAdd: (newEx) {
                              setModalState(() {
                                tempExercises.add(newEx);
                              });
                            },
                          );
                        },
                        icon: const Icon(
                          Icons.add,
                          color: Color(0xFFFF9700),
                          size: 18,
                        ),
                        label: const Text(
                          'Aggiungi',
                          style: TextStyle(
                            color: Color(0xFFFF9700),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Lista Riordinabile degli Esercizi
                  Expanded(
                    child:
                        tempExercises.isEmpty
                            ? Center(
                              child: Text(
                                'Nessun esercizio inserito.\nTocca "+ Aggiungi" per selezionarne uno.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 13,
                                ),
                              ),
                            )
                            : ReorderableListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: tempExercises.length,
                              onReorder: (oldIdx, newIdx) {
                                setModalState(() {
                                  if (newIdx > oldIdx) newIdx -= 1;
                                  final item = tempExercises.removeAt(oldIdx);
                                  tempExercises.insert(newIdx, item);
                                });
                              },
                              itemBuilder: (context, exIdx) {
                                final ex = tempExercises[exIdx];
                                return Container(
                                  key: ValueKey(ex['name'] + exIdx.toString()),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF141414),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.drag_handle_rounded,
                                        color: Colors.white30,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ex['name'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${ex['muscle']} • ${ex['sets']} serie × ${ex['reps']}',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setModalState(() {
                                            tempExercises.removeAt(exIdx);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),

                  const SizedBox(height: 12),

                  // Tasto Salva Scheda
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Inserisci un nome per la scheda'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          final newRoutineData = {
                            'id':
                                existingRoutine?['id'] ??
                                DateTime.now().millisecondsSinceEpoch,
                            'name': nameController.text.trim(),
                            'notes': notesController.text.trim(),
                            'exercises': tempExercises,
                          };

                          if (index != null) {
                            _routines[index] = newRoutineData;
                          } else {
                            _routines.add(newRoutineData);
                          }
                        });

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Salva Scheda',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Selettore rapido con catalogo per gruppi muscolari
  void _showAddExercisePicker({required Function(Map<String, dynamic>) onAdd}) {
    final List<Map<String, dynamic>> catalog = [
      {
        'name': 'Panca Piana Bilanciere',
        'muscle': 'Chest',
        'sets': 4,
        'reps': '6-8',
      },
      {
        'name': 'Spinte Manubri Inclinata',
        'muscle': 'Chest',
        'sets': 3,
        'reps': '8-10',
      },
      {'name': 'Croci ai Cavi', 'muscle': 'Chest', 'sets': 3, 'reps': '12'},
      {
        'name': 'Trazioni alla Sbarra',
        'muscle': 'Back',
        'sets': 4,
        'reps': '6-8',
      },
      {'name': 'Rematore Bilanciere', 'muscle': 'Back', 'sets': 4, 'reps': '8'},
      {'name': 'Lat Machine Avanti', 'muscle': 'Back', 'sets': 3, 'reps': '10'},
      {'name': 'Squat Bilanciere', 'muscle': 'Legs', 'sets': 4, 'reps': '6'},
      {'name': 'Leg Press 45°', 'muscle': 'Legs', 'sets': 3, 'reps': '10'},
      {
        'name': 'Leg Curl Flessioni',
        'muscle': 'Hamstrings',
        'sets': 4,
        'reps': '10-12',
      },
      {'name': 'Military Press', 'muscle': 'Shoulders', 'sets': 4, 'reps': '8'},
      {
        'name': 'Alzate Laterali Manubri',
        'muscle': 'Shoulders',
        'sets': 4,
        'reps': '12-15',
      },
      {
        'name': 'Curl Bilanciere Sagomato',
        'muscle': 'Biceps',
        'sets': 4,
        'reps': '10',
      },
      {'name': 'French Press', 'muscle': 'Triceps', 'sets': 4, 'reps': '10'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          itemCount: catalog.length,
          itemBuilder: (context, i) {
            final item = catalog[i];
            return ListTile(
              leading: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFFFF9700),
              ),
              title: Text(
                item['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                item['muscle'],
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                onAdd(item);
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }
}
