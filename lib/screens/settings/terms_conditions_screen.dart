import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/consent_service.dart';
import 'package:wellspring/theme.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  final ConsentService _consentService = ConsentService();
  ConsentDocument? _document;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final doc =
          await _consentService.getActiveDocument('terms_and_conditions');
      setState(() {
        _document = doc;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TermsConditionsScreen: Failed to load document: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                    AppSpacing.lg, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_document?.title ?? 'Terms & Conditions',
                        style: context.textStyles.headlineSmall?.semiBold),
                    SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (_document != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Version ${_document!.version}',
                                style: context.textStyles.labelSmall
                                    ?.withColor(cs.onPrimaryContainer)),
                          ),
                        if (_document != null) SizedBox(width: AppSpacing.sm),
                        Text(
                            'Effective: ${_formatDate(_document?.effectiveDate)}',
                            style: context.textStyles.bodyMedium
                                ?.withColor(cs.onSurfaceVariant)),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg),
                    if (_document != null)
                      SelectableText(
                        _document!.content,
                        style: context.textStyles.bodyMedium,
                      )
                    else
                      Text('No terms document available.',
                          style: context.textStyles.bodyMedium
                              ?.withColor(cs.error)),
                    SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text('© ${DateTime.now().year} Adaptly',
                          style: context.textStyles.labelMedium
                              ?.withColor(cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.month}/${date.day}/${date.year}';
  }
}
