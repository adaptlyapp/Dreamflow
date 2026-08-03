import 'package:flutter/material.dart';
import 'package:wellspring/utils/firebase_to_supabase_migration.dart';

/// Admin screen for migrating Firebase data to Supabase
/// 
/// This screen provides controls to:
/// - Migrate all Firebase data to Supabase
/// - Clear Supabase data (use with caution!)
/// - View migration progress in real-time
class DataMigrationScreen extends StatefulWidget {
  const DataMigrationScreen({super.key});

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  bool _isMigrating = false;
  bool _migrationComplete = false;
  String? _errorMessage;

  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _migrationComplete = false;
      _errorMessage = null;
    });

    try {
      await FirebaseToSupabaseMigration.migrateAllData();
      
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _migrationComplete = true;
        });
        
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _errorMessage = e.toString();
        });
        
        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _clearSupabaseData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear All Supabase Data?'),
        content: const Text(
          'This will permanently delete ALL data in your Supabase database. '
          'This action cannot be undone.\n\n'
          'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isMigrating = true);

    try {
      await FirebaseToSupabaseMigration.clearSupabaseData();
      
      if (mounted) {
        setState(() => _isMigrating = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ All Supabase data cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMigrating = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to clear data: $e')),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Migration Complete!'),
          ],
        ),
        content: const Text(
          'All Firebase data has been successfully migrated to Supabase.\n\n'
          'You can now verify the data in your Supabase dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Migration Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'An error occurred during migration:\n\n$error\n\n'
            'Check the Debug Console for detailed logs.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase → Supabase Migration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Migration Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• This will copy all data from Firebase Firestore to Supabase\n'
                      '• Existing Supabase data will NOT be deleted\n'
                      '• Duplicate records may be created if run multiple times\n'
                      '• Monitor progress in the Debug Console\n'
                      '• Migration may take several minutes for large datasets',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Migration Status
            if (_isMigrating)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Migration in progress...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check the Debug Console for detailed progress',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            if (_migrationComplete && !_isMigrating)
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Migration Complete!',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('All data has been transferred to Supabase'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_errorMessage != null)
              Card(
                color: Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Migration Failed',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Start Migration Button
            ElevatedButton.icon(
              onPressed: _isMigrating ? null : _startMigration,
              icon: const Icon(Icons.sync),
              label: const Text('Start Migration'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Clear Supabase Data Button
            OutlinedButton.icon(
              onPressed: _isMigrating ? null : _clearSupabaseData,
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Clear Supabase Data'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),

            const SizedBox(height: 32),

            // Collections Overview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collections to Migrate',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '✓ Users\n'
                      '✓ Hospitals\n'
                      '✓ Conditions\n'
                      '✓ Posts & Comments\n'
                      '✓ Groups & Members\n'
                      '✓ Messages\n'
                      '✓ Goals & Milestones\n'
                      '✓ Tracker Entries\n'
                      '✓ Achievements\n'
                      '✓ Resources & Ratings\n'
                      '✓ Resource Suggestions & Applications',
                      style: TextStyle(height: 1.8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
