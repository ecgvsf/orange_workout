import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  final Isar isar;

  const ProfileScreen({super.key, required this.isar});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;

  // Controller per le impostazioni e il tunnel
  final TextEditingController _serverUrlController = TextEditingController();
  bool _autoSyncEnabled = true;
  bool _vibrationEnabled = true;
  String _selectedWeightUnit = 'kg';

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
    // Carica il primo profilo presente o ne crea uno iniziale di default
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

    // Default tunnel endpoint di esempio
    _serverUrlController.text = 'https://workout.tuodominio.it';

    setState(() {
      _isLoading = false;
    });
  }

  // Calcolo del BMI (Indice di Massa Corporea)
  double get _bmi {
    if (_userProfile == null || _userProfile!.height <= 0) return 0.0;
    final heightInMeters = _userProfile!.height / 100;
    return _userProfile!.bodyWeight / (heightInMeters * heightInMeters);
  }

  // Dialog per modificare peso e altezza
  void _editBiometricsDialog() {
    final weightController = TextEditingController(
      text: _userProfile?.bodyWeight.toString() ?? '',
    );
    final heightController = TextEditingController(
      text: _userProfile?.height.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: _userProfile?.name ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Modifica Profilo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(
                  controller: nameController,
                  label: 'Nome',
                  icon: Icons.person_rounded,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 14),
                _buildDialogField(
                  controller: weightController,
                  label: 'Peso corporeo (kg)',
                  icon: Icons.scale_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                _buildDialogField(
                  controller: heightController,
                  label: 'Altezza (cm)',
                  icon: Icons.height_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Annulla',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final newWeight =
                    double.tryParse(weightController.text) ??
                    _userProfile!.bodyWeight;
                final newHeight =
                    double.tryParse(heightController.text) ??
                    _userProfile!.height;
                final newName =
                    nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : _userProfile!.name;

                await widget.isar.writeTxn(() async {
                  _userProfile!
                    ..name = newName
                    ..bodyWeight = newWeight
                    ..height = newHeight;
                  await widget.isar.userProfiles.put(_userProfile!);
                });

                setState(() {});
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Salva',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFFFF9700), size: 20),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF9700)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER PROFILO ---
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF9700),
                        width: 2,
                      ),
                      color: const Color(0xFF1E1E1E),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFFFF9700),
                      size: 40,
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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Hypertrophy',
                            style: TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _editBiometricsDialog,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFFFF9700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFFF9700), thickness: 3, height: 1),
              const SizedBox(height: 20),

              // --- PARAMETRI BIOMETRICI (CARD STATS) ---
              const Text(
                'Parametri Biometrici',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildBiometricCard(
                    title: 'Peso',
                    value: '${_userProfile?.bodyWeight.toStringAsFixed(1)}',
                    unit: 'kg',
                    icon: Icons.scale_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildBiometricCard(
                    title: 'Altezza',
                    value: '${_userProfile?.height.toStringAsFixed(0)}',
                    unit: 'cm',
                    icon: Icons.height_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildBiometricCard(
                    title: 'BMI',
                    value: _bmi.toStringAsFixed(1),
                    unit: 'indice',
                    icon: Icons.monitor_weight_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- SEZIONE RASPBERRY & CLOUD SYNC ---
              const Text(
                'Sincronizzazione Cloud',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Backup Automatico in Cloud',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Invia i log al Server al termine del workout',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      value: _autoSyncEnabled,
                      activeColor: const Color(0xFFFF9700),
                      onChanged: (val) {
                        setState(() => _autoSyncEnabled = val);
                      },
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.greenAccent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Ultimo backup: Oggi, 18:30',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C2C2E),
                            foregroundColor: const Color(0xFFFF9700),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sincronizzazione avviata...'),
                                backgroundColor: Color(0xFF1E1E1E),
                              ),
                            );
                          },
                          child: const Text(
                            'Sincronizza ora',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- IMPOSTAZIONI & PREFERENZE ---
              const Text(
                'Preferenze Allenamento',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.fitness_center_rounded,
                        color: Color(0xFFFF9700),
                      ),
                      title: const Text(
                        'Unità di Misura Carico',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      trailing: DropdownButton<String>(
                        value: _selectedWeightUnit,
                        dropdownColor: const Color(0xFF1E1E1E),
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontWeight: FontWeight.bold,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'kg', child: Text('kg')),
                          DropdownMenuItem(value: 'lbs', child: Text('lbs')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedWeightUnit = v);
                          }
                        },
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFFFF9700),
                      ),
                      title: const Text(
                        'Timer Recupero Predefinito',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      trailing: const Text(
                        '90s',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {},
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.vibration_rounded,
                        color: Color(0xFFFF9700),
                      ),
                      title: const Text(
                        'Feedback Aptico alla Fine del Set',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      trailing: Switch(
                        value: _vibrationEnabled,
                        activeColor: const Color(0xFFFF9700),
                        onChanged: (val) {
                          setState(() => _vibrationEnabled = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Spazio per non coprire i contenuti con la FloatingNavBar
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // Costruttore per i blocchi statistici biometrici
  Widget _buildBiometricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF9700), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$title ($unit)',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
