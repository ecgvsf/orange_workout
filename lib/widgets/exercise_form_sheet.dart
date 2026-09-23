import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';

class ExerciseFormSheet extends StatefulWidget {
  final Isar isar;
  final Exercise? existing;
  final ValueChanged<Exercise>? onSaved;

  const ExerciseFormSheet({
    super.key,
    required this.isar,
    this.existing,
    this.onSaved,
  });

  /// Metodo statico comodo per aprire la modale
  static Future<Exercise?> show(
    BuildContext context, {
    required Isar isar,
    Exercise? existing,
  }) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => ExerciseFormSheet(isar: isar, existing: existing),
    );
  }

  @override
  State<ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<ExerciseFormSheet> {
  late final TextEditingController _nameController;

  late ExerciseType _exerciseType;
  late String _selectedMuscle;
  late bool _isCompound;
  late String _selectedEquipment;
  String? _currentImagePath;
  late List<String> _selectedSecondaryMuscles;

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

  final List<String> _equipmentOptions = const [
    'Bilanciere',
    'Manubri',
    'Cavi',
    'Macchinario',
    'Corpo Libero',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameController = TextEditingController(text: ex?.name ?? '');
    _selectedMuscle = ex?.muscleGroup ?? _muscleCategories.first;
    _isCompound = ex?.isCompound ?? false;
    _exerciseType = ex?.exerciseType ?? ExerciseType.reps;
    _selectedEquipment = ex?.equipment ?? 'Bilanciere';
    _currentImagePath = ex?.imagePath;
    _selectedSecondaryMuscles =
        ex != null ? List<String>.from(ex.secondaryMuscles) : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'ex_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File permanentFile = await File(
        pickedFile.path,
      ).copy('${appDir.path}/$fileName');

      setState(() {
        _currentImagePath = permanentFile.path;
      });
    }
  }

  Future<void> _saveExercise() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final target = widget.existing ?? Exercise();
    target.name = name;
    target.muscleGroup = _selectedMuscle;
    target.isCompound = _isCompound;
    target.equipment = _selectedEquipment;
    target.exerciseType = _exerciseType;
    target.imagePath = _currentImagePath;
    target.secondaryMuscles = _isCompound ? _selectedSecondaryMuscles : [];

    await widget.isar.writeTxn(() async {
      await widget.isar.exercises.put(target);
    });

    if (widget.onSaved != null) {
      widget.onSaved!(target);
    }

    if (mounted) {
      Navigator.pop(context, target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> availableSecondaryCategories =
        _muscleCategories.where((m) => m != _selectedMuscle).toList();

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
              widget.existing == null
                  ? 'Nuovo Esercizio'
                  : 'Modifica Esercizio',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // --- SELETTORE IMMAGINE ---
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _currentImagePath != null
                              ? const Color(0xFFFF9700).withValues(alpha: 0.6)
                              : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child:
                      _currentImagePath != null &&
                              File(_currentImagePath!).existsSync()
                          ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.file(
                                  File(_currentImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.black.withValues(alpha: 0.25),
                                ),
                              ),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
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
                                    setState(() => _currentImagePath = null);
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
              controller: _nameController,
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

            // --- DROPDOWN MUSCOLO + ATTREZZATURA ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Gruppo Primario
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
                      _buildDropdown(
                        value:
                            _muscleCategories.contains(_selectedMuscle)
                                ? _selectedMuscle
                                : _muscleCategories.first,
                        icon: Icons.accessibility_new_rounded,
                        items: _muscleCategories,
                        onChanged: (v) {
                          if (v != null) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedMuscle = v;
                              _selectedSecondaryMuscles.remove(v);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // 2. Attrezzatura
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
                      _buildDropdown(
                        value:
                            _equipmentOptions.contains(_selectedEquipment)
                                ? _selectedEquipment
                                : _equipmentOptions.first,
                        icon: Icons.fitness_center_rounded,
                        items: _equipmentOptions,
                        onChanged: (v) {
                          if (v != null) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedEquipment = v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const Text(
              'Modalità di Esecuzione',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<ExerciseType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Reps',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    value: ExerciseType.reps,
                    groupValue: _exerciseType,
                    activeColor: const Color(0xFFFF9700),
                    onChanged: (val) => setState(() => _exerciseType = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<ExerciseType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tempo (s)',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    value: ExerciseType.time,
                    groupValue: _exerciseType,
                    activeColor: const Color(0xFFFF9700),
                    onChanged: (val) => setState(() => _exerciseType = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // --- SWITCH COMPOUND ---
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
              value: _isCompound,
              activeColor: const Color(0xFFFF9700),
              onChanged: (v) {
                setState(() {
                  _isCompound = v;
                  if (!_isCompound) {
                    _selectedSecondaryMuscles.clear();
                  }
                });
              },
            ),

            // --- SEZIONE MUSCOLI SECONDARI ---
            if (_isCompound) ...[
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
                    '${_selectedSecondaryMuscles.length} selezionati',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    availableSecondaryCategories.map((muscle) {
                      final isSelected = _selectedSecondaryMuscles.contains(
                        muscle,
                      );
                      return FilterChip(
                        label: Text(muscle),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSecondaryMuscles.add(muscle);
                            } else {
                              _selectedSecondaryMuscles.remove(muscle);
                            }
                          });
                        },
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        selectedColor: const Color(0xFFFF9700),
                        backgroundColor: const Color(0xFF141414),
                        checkmarkColor: Colors.white,
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
                onPressed: _saveExercise,
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
  }

  Widget _buildDropdown({
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(18),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFFF9700),
              size: 22,
            ),
            selectedItemBuilder: (context) {
              return items.map((val) {
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFFFF9700),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        val,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items:
                items.map((val) {
                  final isSelected = val == value;
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(
                                  0xFFFF9700,
                                ).withValues(alpha: 0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFFFF9700)
                                  : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            val,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? const Color(0xFFFF9700)
                                      : Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: Color(0xFFFF9700),
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
