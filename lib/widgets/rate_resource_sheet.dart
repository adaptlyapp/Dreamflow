import 'package:flutter/material.dart';
import 'package:wellspring/services/ratings_service.dart';
import 'package:wellspring/theme.dart';

class RateResourceSheet extends StatefulWidget {
  final String resourceId;
  final String resourceName;
  const RateResourceSheet({super.key, required this.resourceId, required this.resourceName});

  @override
  State<RateResourceSheet> createState() => _RateResourceSheetState();
}

class _RateResourceSheetState extends State<RateResourceSheet> {
  int _stars = 0;
  final _controller = TextEditingController();
  bool _submitting = false;
  final _svc = RatingsService();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _star(int i) {
    final cs = Theme.of(context).colorScheme;
    final filled = i <= _stars;
    return IconButton(
      onPressed: _submitting ? null : () => setState(() => _stars = i),
      icon: Icon(filled ? Icons.star : Icons.star_border),
      color: filled ? cs.primary : cs.onSurfaceVariant,
    );
  }

  Future<void> _submit() async {
    if (_stars < 1) return;
    setState(() => _submitting = true);
    try {
      await _svc.submitReview(
        resourceId: widget.resourceId,
        stars: _stars,
        comment: _controller.text.trim().isEmpty ? null : _controller.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit review: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.rate_review, color: cs.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Rate ${widget.resourceName}', style: context.textStyles.titleLarge?.semiBold)),
            ]),
            SizedBox(height: AppSpacing.md),
            Row(children: List.generate(5, (i) => _star(i + 1))),
            SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Optional comment'),
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_submitting || _stars < 1) ? null : _submit,
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(_submitting ? 'Submitting…' : 'Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
