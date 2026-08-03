import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';

class FamilyConnectionDebugScreen extends StatefulWidget {
  const FamilyConnectionDebugScreen({super.key});

  @override
  State<FamilyConnectionDebugScreen> createState() => _FamilyConnectionDebugScreenState();
}

class _FamilyConnectionDebugScreenState extends State<FamilyConnectionDebugScreen> {
  final _familyService = FamilyService();
  final _userService = UserService();
  final _supabase = SupabaseConfig.client;
  List<PatientConnection>? _connections;
  bool _loading = true;
  bool _lookingUp = false;
  final _correctPatientIdController = TextEditingController(
    text: '7744126d-bfa6-4e3b-b735-23674993f3b4',
  );
  final _patientEmailController = TextEditingController(
    text: 'dpaine170014@gmail.com',
  );
  String? _lookupResult;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _correctPatientIdController.dispose();
    _patientEmailController.dispose();
    super.dispose();
  }

  Future<void> _lookupPatientByEmail() async {
    final email = _patientEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _lookupResult = 'Please enter patient email');
      return;
    }

    setState(() {
      _lookingUp = true;
      _lookupResult = null;
    });

    try {
      final data = await _supabase
          .from('users')
          .select('id, name, email, patient_code, conditions')
          .eq('email', email)
          .eq('role', 'patient')
          .maybeSingle();

      if (data == null) {
        setState(() {
          _lookupResult = '❌ No patient found with email: $email';
          _lookingUp = false;
        });
        return;
      }

      final patientId = data['id'] as String;
      final patientName = data['name'] as String;
      final patientCode = data['patient_code'] as String?;
      final conditions = data['conditions'] as List?;

      // Check for milestones
      final milestones = await _supabase
          .from('milestones')
          .select('id, title, completed')
          .eq('user_id', patientId);
      
      // Check for goals
      final goals = await _supabase
          .from('goals')
          .select('id, title, active')
          .eq('user_id', patientId);

      _correctPatientIdController.text = patientId;
      
      setState(() {
        _lookupResult = '✅ Found patient!\n'
            'Name: $patientName\n'
            'ID: $patientId\n'
            'Code: ${patientCode ?? 'N/A'}\n'
            'Conditions: ${conditions?.join(', ') ?? 'None'}\n'
            '\n📊 JOURNEY DATA:\n'
            'Milestones: ${milestones.length} found\n'
            'Goals: ${goals.length} found\n'
            '${milestones.isEmpty ? '\n⚠️ NO MILESTONES IN DATABASE!' : '\nSample: ${milestones.first['title']}'}';
        _lookingUp = false;
      });
    } catch (e) {
      setState(() {
        _lookupResult = '❌ Error: $e';
        _lookingUp = false;
      });
    }
  }

  Future<void> _loadConnections() async {
    setState(() => _loading = true);
    try {
      final user = await _userService.getCurrentUser();
      if (user != null) {
        final connections = await _familyService.getConnectionsForFamily(user.id);
        setState(() {
          _connections = connections;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading connections: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _fixConnection(PatientConnection connection) async {
    try {
      final correctId = _correctPatientIdController.text.trim();
      if (correctId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the correct patient ID first')),
        );
        return;
      }

      // Delete old connection and create new one with correct ID
      final user = await _userService.getCurrentUser();
      if (user == null) return;

      await _familyService.connectToPatient(
        familyMemberId: user.id,
        patientId: correctId,
        patientName: connection.patientName,
        relationship: connection.relationship,
        patientProfileImageUrl: connection.patientProfileImageUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Connection fixed! Reload the app.')),
      );
      await _loadConnections();
    } catch (e) {
      debugPrint('Error fixing connection: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Patient Connections'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔍 Look Up Patient by Email',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Enter the patient\'s email address to find their correct user ID:',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _patientEmailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Patient Email',
                                    hintText: 'dpaine170014@gmail.com',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              FilledButton(
                                onPressed: _lookingUp ? null : _lookupPatientByEmail,
                                child: _lookingUp
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Look Up'),
                              ),
                            ],
                          ),
                          if (_lookupResult != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _lookupResult!.startsWith('✅')
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              child: Text(
                                _lookupResult!,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚠️ Fix Patient Connection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'After looking up the patient above, verify the ID below is correct, '
                            'then click "Fix Connection" on your connection card.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: _correctPatientIdController,
                            decoration: const InputDecoration(
                              labelText: 'Correct Patient User ID',
                              hintText: '7744126d-bfa6-4e3b-b735-23674993f3b4',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    'Current Connections:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_connections == null || _connections!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('No connections found'),
                      ),
                    )
                  else
                    ..._connections!.map((connection) => Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            connection.patientName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            connection.relationship,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () => _fixConnection(connection),
                                      child: const Text('Fix Connection'),
                                    ),
                                  ],
                                ),
                                const Divider(height: AppSpacing.lg),
                                const Text(
                                  'CURRENT (WRONG) PATIENT ID:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        connection.patientId,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: connection.patientId),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Copied to clipboard')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Connected: ${connection.connectedAt}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
