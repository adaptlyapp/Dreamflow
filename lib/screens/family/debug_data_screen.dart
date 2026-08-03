import 'package:flutter/material.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';

class DebugDataScreen extends StatefulWidget {
  const DebugDataScreen({super.key});

  @override
  State<DebugDataScreen> createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends State<DebugDataScreen> {
  bool _loading = false;
  String _result = '';

  Future<void> _testDirectQuery() async {
    setState(() {
      _loading = true;
      _result = 'Testing direct database query...\n\n';
    });

    try {
      final authUser = SupabaseConfig.client.auth.currentUser;
      if (authUser == null) {
        _result += '❌ No authenticated user\n';
        setState(() => _loading = false);
        return;
      }

      _result += '═══════════════════════════════════════\n';
      _result += 'AUTH USER INFO\n';
      _result += '═══════════════════════════════════════\n';
      _result += 'Auth User ID: ${authUser.id}\n';
      _result += 'Email: ${authUser.email}\n\n';

      _result += '═══════════════════════════════════════\n';
      _result += 'ALL PROFILES FOR THIS AUTH USER\n';
      _result += '═══════════════════════════════════════\n';
      
      final allProfiles = await SupabaseConfig.client
          .from('users')
          .select('id, auth_user_id, name, role, patient_code, created_at')
          .eq('auth_user_id', authUser.id)
          .order('created_at', ascending: false);
      
      if (allProfiles.isEmpty) {
        _result += '❌ No profiles found!\n\n';
      } else {
        _result += 'Found ${allProfiles.length} profile(s):\n\n';
        for (int i = 0; i < allProfiles.length; i++) {
          final profile = allProfiles[i];
          _result += '${i + 1}. ${profile['role'].toString().toUpperCase()} PROFILE\n';
          _result += '   Profile ID: ${profile['id']}\n';
          _result += '   Name: ${profile['name']}\n';
          _result += '   Patient Code: ${profile['patient_code'] ?? '(none)'}\n';
          _result += '   Created: ${profile['created_at']}\n\n';
        }
      }

      // Find the patient profile
      final patientProfile = allProfiles.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['role'] == 'patient',
        orElse: () => null,
      );

      if (patientProfile == null) {
        _result += '❌ No patient profile found for this auth user\n\n';
        setState(() => _loading = false);
        return;
      }

      final patientId = patientProfile['id'] as String;
      _result += '═══════════════════════════════════════\n';
      _result += 'TESTING WITH PATIENT PROFILE\n';
      _result += '═══════════════════════════════════════\n';
      _result += 'Using Patient ID: $patientId\n\n';

      _result += '1. Checking tracker entries for patient...\n';
      final trackerData = await SupabaseConfig.client
          .from('tracker_entries')
          .select('id, date, pain_level, sleep_quality, energy_level')
          .eq('user_id', patientId)
          .order('date', ascending: false)
          .limit(5);
      
      _result += '   ✓ Found ${trackerData.length} entries\n';
      if (trackerData.isNotEmpty) {
        _result += '   Recent entries:\n';
        for (final entry in trackerData) {
          _result += '     - ${entry['date']}: Pain=${entry['pain_level']}, Sleep=${entry['sleep_quality']}, Energy=${entry['energy_level']}\n';
        }
      } else {
        _result += '   ⚠️  No tracker entries found\n';
      }
      _result += '\n';

      _result += '2. Testing edge function with CORRECT patient ID...\n';
      int? apiStatus;
      try {
        final response = await SupabaseConfig.client.functions.invoke(
          'family-portal-patient-data',
          queryParameters: {'patientId': patientId},
        );

        apiStatus = response.status;
        _result += '   Status: ${response.status}\n';
        if (response.status == 200) {
          final data = response.data as Map<String, dynamic>;
          _result += '   ✅ API Success!\n';
          _result += '   Entry count: ${data['entryCount']}\n';
          _result += '   Milestones: ${(data['milestones'] as List?)?.length ?? 0}\n';
          _result += '   Goals: ${(data['goals'] as List?)?.length ?? 0}\n';
        } else {
          _result += '   ❌ API Error: ${response.data}\n';
        }
      } catch (e) {
        _result += '   ❌ API Exception: $e\n';
        apiStatus = null;
      }
      _result += '\n';

      _result += '═══════════════════════════════════════\n';
      _result += 'DIAGNOSIS\n';
      _result += '═══════════════════════════════════════\n';
      
      if (patientProfile['id'] == patientProfile['auth_user_id']) {
        _result += '✓ Patient profile ID matches auth_user_id\n';
        _result += '  This is a legacy account setup.\n\n';
      } else {
        _result += '⚠️  Patient profile ID differs from auth_user_id\n';
        _result += '  Profile ID: ${patientProfile['id']}\n';
        _result += '  Auth User ID: ${patientProfile['auth_user_id']}\n\n';
      }
      
      _result += 'Tracker entries exist: ${trackerData.isNotEmpty ? "YES" : "NO"}\n';
      _result += 'Edge function works: ${apiStatus == 200 ? "YES" : "NO"}\n\n';
      
      if (apiStatus != 200) {
        _result += '❌ ISSUE: Edge function cannot access patient data\n';
        _result += 'Possible causes:\n';
        _result += '  1. Edge function not redeployed with latest code\n';
        _result += '  2. RLS policy blocking service role access\n';
        _result += '  3. Patient role field case mismatch (\'Patient\' vs \'patient\')\n\n';
        _result += 'ACTION NEEDED:\n';
        _result += '  → Redeploy family-portal-patient-data function via Supabase panel\n';
        _result += '  → Check Supabase edge function logs for server-side errors\n';
        _result += '  → Verify patient.role is exactly \'patient\' (lowercase)\n';
      }

    } catch (e, stack) {
      _result += '\n❌ ERROR: $e\n';
      _result += 'Stack: $stack\n';
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Patient Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _testDirectQuery,
              child: _loading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run Diagnostic Test'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SelectableText(
                      _result.isEmpty ? 'Tap button to run test' : _result,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
