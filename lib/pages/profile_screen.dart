import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../utils/weight_converter.dart';

class ProfileScreen extends StatefulWidget {
  final Isar isar;

  const ProfileScreen({super.key, required this.isar});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;

  // Immagine e Sesso salvati su SharedPreferences
  String? _profileImagePath;
  String _gender = 'Maschio';

  // Cloud & Backup
  final TextEditingController _serverUrlController = TextEditingController();
  bool _autoSyncEnabled = true;
  bool _isSyncing = false;
  String _lastSyncText = 'Oggi, 18:30';

  // Preferenze Globali Allenamento
  String _selectedWeightUnit = 'kg';
  int _defaultRestSeconds = 90;
  double _minWeightIncrement = 2.5;
  bool _hapticEnabled = true;
  bool _keepScreenOn = true;

  // Obiettivo & Livello
  String _fitnessGoal = 'Hypertrophy';
  String _experienceLevel = 'Intermedio';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final profile = await widget.isar.userProfiles.where().findFirst();
    if (profile == null) {
      final defaultProfile =
          UserProfile()
            ..name = 'Atleta'
            ..bodyWeight = 75.0
            ..height = 180.0;

      await widget.isar.writeTxn(() async {
        await widget.isar.userProfiles.put(defaultProfile);
      });
      _userProfile = defaultProfile;
    } else {
      _userProfile = profile;
    }

    final prefs = await SharedPreferences.getInstance();
    _selectedWeightUnit = prefs.getString('global_weight_unit') ?? 'kg';
    GlobalSettings.weightUnitNotifier.value = _selectedWeightUnit;

    _serverUrlController.text = 'https://282004.xyz';

    setState(() {
      // Caricamento preferenze da SharedPreferences
      _selectedWeightUnit = prefs.getString('global_weight_unit') ?? 'kg';
      _defaultRestSeconds = prefs.getInt('global_rest_time') ?? 90;
      _minWeightIncrement = prefs.getDouble('global_weight_increment') ?? 2.5;
      _profileImagePath = prefs.getString('profile_image_path');
      _gender = prefs.getString('user_gender') ?? 'Maschio';

      _isLoading = false;
    });
  }

  double get _bmi {
    if (_userProfile == null || _userProfile!.height <= 0) return 0.0;
    final hInMeters = _userProfile!.height / 100;
    return _userProfile!.bodyWeight / (hInMeters * hInMeters);
  }

  String get _bmiCategory {
    final val = _bmi;
    if (val < 18.5) return 'Sottopeso';
    if (val < 25.0) return 'Normopeso';
    if (val < 30.0) return 'Massa Muscolare';
    return 'Alta Densità';
  }

  // --- MODALE MODIFICA (STATO SEPARATO PER GESTIRE IMMAGINE E SESSO DINAMICAMENTE) ---
  void _openEditBiometricsSheet() {
    if (_hapticEnabled) HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _EditProfileSheet(
          isar: widget.isar,
          userProfile: _userProfile!,
          initialImagePath: _profileImagePath,
          initialGender: _gender,
          weightUnit: _selectedWeightUnit,
          onSaved: (newImage, newGender) {
            setState(() {
              _profileImagePath = newImage;
              _gender = newGender;
              _loadUserData(); // Ricarica le info salvate nel database
            });
          },
        );
      },
    );
  }

  Future<void> _performCloudSync() async {
    if (_hapticEnabled) HapticFeedback.selectionClick();
    setState(() => _isSyncing = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastSyncText = 'Pochi secondi fa';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFF9700), width: 1),
        ),
        content: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 22),
            SizedBox(width: 12),
            Text(
              'Database sincronizzato con il Raspberry!',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF9700)),
        ),
      );
    }

    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double cutOffBottom = (bottomInset).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: cutOffBottom),
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.05, 0.94, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO HEADER ATLETA
                  _buildAthleteHeader(),
                  const SizedBox(height: 20),

                  // 2. STATISTICHE BIOMETRICHE
                  _buildSectionTitle('Parametri Biometrici'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // La card diventa cliccabile per aprire l'editor
                      _buildBiometricCard(
                        title: 'Peso',
                        value: '${_userProfile?.bodyWeight.toStringAsFixed(1)}',
                        unit: _selectedWeightUnit,
                        icon: Icons.scale_rounded,
                        accentColor: const Color(0xFFFF9700),
                        onTap: _openEditBiometricsSheet,
                      ),
                      const SizedBox(width: 10),
                      _buildBiometricCard(
                        title: 'Altezza',
                        value: '${_userProfile?.height.toStringAsFixed(0)}',
                        unit: 'cm',
                        icon: Icons.height_rounded,
                        accentColor: const Color(0xFFFFB74D),
                        onTap: _openEditBiometricsSheet,
                      ),
                      const SizedBox(width: 10),
                      _buildBiometricCard(
                        title: 'BMI',
                        value: _bmi.toStringAsFixed(1),
                        unit: _bmiCategory,
                        icon: Icons.monitor_weight_outlined,
                        accentColor: Colors.white70,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 3. TARGET ATLETICO
                  _buildSectionTitle('Programmazione & Focus'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              color: Color(0xFFFF9700),
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Obiettivo Attuale',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildGoalGrid(),
                        const SizedBox(height: 14),
                        _buildSegmentPicker(
                          icon: Icons.military_tech_rounded,
                          title: 'Livello Atletico',
                          value: _experienceLevel,
                          options: const [
                            'Principiante',
                            'Intermedio',
                            'Avanzato',
                          ],
                          onSelected:
                              (val) => setState(() => _experienceLevel = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. PREFERENZE IN SALA PESI (CON SHARED PREFS)
                  _buildSectionTitle('Preferenze in Sessione'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildInlineOption(
                          icon: Icons.fitness_center_rounded,
                          title: 'Unità Carico',
                          subtitle: 'Sistema di misura per serie e bilancieri',
                          customControl: _buildPillSelector<String>(
                            values: const ['kg', 'lbs'],
                            selectedValue: _selectedWeightUnit,
                            onChanged: (val) async {
                              setState(() => _selectedWeightUnit = val);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString('global_weight_unit', val);
                              GlobalSettings.weightUnitNotifier.value = val;
                            },
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 1),
                        _buildInlineOption(
                          icon: Icons.timer_outlined,
                          title: 'Recupero Standard',
                          subtitle: 'Timer automatico dopo ogni set completato',
                          customControl: _buildPillSelector<int>(
                            values: const [60, 90, 120, 180],
                            displayValues: const ['60s', '90s', '2m', '3m'],
                            selectedValue: _defaultRestSeconds,
                            onChanged: (val) async {
                              setState(() => _defaultRestSeconds = val);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setInt('global_rest_time', val);
                            },
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 1),
                        _buildInlineOption(
                          icon: Icons.exposure_plus_1_rounded,
                          title: 'Incremento Minimo',
                          subtitle: 'Scatto manopola per la regolazione dischi',
                          customControl: _buildPillSelector<double>(
                            values: const [0.5, 1.25, 2.5, 5.0],
                            displayValues: [
                              '0.5 $_selectedWeightUnit',
                              '1.25 $_selectedWeightUnit',
                              '2.5 $_selectedWeightUnit',
                              '5.0 $_selectedWeightUnit',
                            ],
                            selectedValue: _minWeightIncrement,
                            onChanged: (val) async {
                              setState(() => _minWeightIncrement = val);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setDouble(
                                'global_weight_increment',
                                val,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- COMPONENTI UI ---

  Widget _buildAthleteHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openEditBiometricsSheet,
            child: Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2C2C2E),
                    border: Border.all(
                      color: const Color(0xFFFF9700),
                      width: 2,
                    ),
                  ),
                  child:
                      _profileImagePath != null &&
                              File(_profileImagePath!).existsSync()
                          ? ClipOval(
                            child: Image.file(
                              File(_profileImagePath!),
                              fit: BoxFit.cover,
                            ),
                          )
                          : const Icon(
                            Icons.person_rounded,
                            color: Color(0xFFFF9700),
                            size: 34,
                          ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9700),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userProfile?.name ?? 'Atleta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fitnessGoal,
                        style: const TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _gender,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openEditBiometricsSheet,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFFFF9700),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
          ),
          child: Column(
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$title ($unit)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget customControl,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF9700), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          customControl,
        ],
      ),
    );
  }

  Widget _buildPillSelector<T>({
    required List<T> values,
    List<String>? displayValues,
    required T selectedValue,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(values.length, (idx) {
          final val = values[idx];
          final text =
              displayValues != null ? displayValues[idx] : val.toString();
          final isSelected = val == selectedValue;

          return GestureDetector(
            onTap: () {
              if (_hapticEnabled) HapticFeedback.selectionClick();
              onChanged(val);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFFFF9700) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSegmentPicker({
    required IconData icon,
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFF9700), size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((opt) {
                final isSelected = opt == value;
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(opt),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  selected: isSelected,
                  side: BorderSide(
                    color:
                        isSelected ? const Color(0xFFFF9700) : Colors.white10,
                    width: 1.5,
                  ),
                  selectedColor: const Color(0xFFFF9700),
                  backgroundColor: const Color(0xFF141414),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (_) {
                    if (_hapticEnabled) HapticFeedback.selectionClick();
                    onSelected(opt);
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildGoalGrid() {
    final List<Map<String, dynamic>> goals = [
      {
        'id': 'Hypertrophy',
        'label': 'Ipertrofia',
        'desc': 'Volume',
        'icon': Icons.fitness_center_rounded,
      },
      {
        'id': 'Strength',
        'label': 'Forza',
        'desc': 'Progressione',
        'icon': Icons.bolt_rounded,
      },
      {
        'id': 'Cut / Shred',
        'label': 'Definizione',
        'desc': 'Densità',
        'icon': Icons.local_fire_department_rounded,
      },
      {
        'id': 'Maintenance',
        'label': 'Mantenimento',
        'desc': 'Ricomposizione',
        'icon': Icons.balance_rounded,
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildGoalCard(goals[0]),
            const SizedBox(width: 8),
            _buildGoalCard(goals[1]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildGoalCard(goals[2]),
            const SizedBox(width: 8),
            _buildGoalCard(goals[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final bool isSelected = _fitnessGoal == goal['id'];
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_hapticEnabled) HapticFeedback.selectionClick();
          setState(() => _fitnessGoal = goal['id'] as String);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFFF9700) : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF9700) : Colors.white10,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    goal['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.white54,
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                goal['label'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET SEPARATO PER LA MODALE (Gestione fluida di Immagine e Tastiera) ---
class _EditProfileSheet extends StatefulWidget {
  final Isar isar;
  final UserProfile userProfile;
  final String? initialImagePath;
  final String initialGender;
  final String weightUnit;
  final Function(String?, String) onSaved;

  const _EditProfileSheet({
    required this.isar,
    required this.userProfile,
    required this.initialImagePath,
    required this.initialGender,
    required this.weightUnit,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController nameCtrl;
  late TextEditingController weightCtrl;
  late TextEditingController heightCtrl;

  String? _tempImagePath;
  String _tempGender = 'Maschio';

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.userProfile.name);
    weightCtrl = TextEditingController(
      text: widget.userProfile.bodyWeight.toString(),
    );
    heightCtrl = TextEditingController(
      text: widget.userProfile.height.toString(),
    );
    _tempImagePath = widget.initialImagePath;
    _tempGender = widget.initialGender;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    weightCtrl.dispose();
    heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _tempImagePath = pickedFile.path);
    }
  }

  Widget _buildGenderButton(String label, IconData icon) {
    final isSelected = _tempGender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tempGender = label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFFF9700) : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF9700) : Colors.white12,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white54,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: Color(0xFFFF9700), size: 24),
              SizedBox(width: 10),
              Text(
                'Modifica Dati Atleta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Selezione Immagine Profilo
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2C2C2E),
                      border: Border.all(
                        color: const Color(0xFFFF9700),
                        width: 2,
                      ),
                    ),
                    child:
                        _tempImagePath != null &&
                                File(_tempImagePath!).existsSync()
                            ? ClipOval(
                              child: Image.file(
                                File(_tempImagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                            : const Icon(
                              Icons.person_rounded,
                              color: Color(0xFFFF9700),
                              size: 40,
                            ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9700),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1E1E1E),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Selettore Genere
          Row(
            children: [
              _buildGenderButton('Maschio', Icons.male_rounded),
              const SizedBox(width: 10),
              _buildGenderButton('Femmina', Icons.female_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // Campi di Testo
          TextField(
            controller: nameCtrl,
            keyboardType: TextInputType.name,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFFF9700),
                size: 20,
              ),
              labelText: 'Nome / Nickname',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF141414),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.scale_rounded,
                      color: Color(0xFFFF9700),
                      size: 20,
                    ),
                    labelText: 'Peso (${widget.weightUnit})',
                    labelStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: heightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.height_rounded,
                      color: Color(0xFFFF9700),
                      size: 20,
                    ),
                    labelText: 'Altezza (cm)',
                    labelStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pulsante Salva
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9700),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final newW =
                    double.tryParse(weightCtrl.text) ??
                    widget.userProfile.bodyWeight;
                final newH =
                    double.tryParse(heightCtrl.text) ??
                    widget.userProfile.height;
                final newN =
                    nameCtrl.text.trim().isNotEmpty
                        ? nameCtrl.text.trim()
                        : widget.userProfile.name;

                // Salva i parametri globali (immagini e sesso) in SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                if (_tempImagePath != null) {
                  await prefs.setString('profile_image_path', _tempImagePath!);
                }
                await prefs.setString('user_gender', _tempGender);

                // Salva le biometriche in Isar
                await widget.isar.writeTxn(() async {
                  final current = await widget.isar.userProfiles.where().findFirst();
                  if (current != null) {
                    current
                      ..name = newN
                      ..bodyWeight = newW
                      ..height = newH;
                    await widget.isar.userProfiles.put(current);
                  } else {
                    widget.userProfile
                      ..name = newN
                      ..bodyWeight = newW
                      ..height = newH;
                    await widget.isar.userProfiles.put(widget.userProfile);
                  }
                });

                HapticFeedback.mediumImpact();
                widget.onSaved(_tempImagePath, _tempGender);
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Salva Modifiche',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
