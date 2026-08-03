import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A simple tappable phone number that launches the dialer using tel: links.
///
/// It tries to normalize common phone formats (keeps leading + and digits), and
/// falls back gracefully if launching fails by showing a SnackBar and logging
/// with debugPrint.
class PhoneLink extends StatelessWidget {
  final String phone;
  final TextStyle? style;
  final bool dense;

  const PhoneLink({super.key, required this.phone, this.style, this.dense = true});

  String _normalize(String input) {
    var s = input.trim();
    // Remove any leading tel: (case-insensitive). Avoid inline (?i) flag for web JS regex.
    s = s.replaceAll(RegExp(r'^tel:', caseSensitive: false), '');
    // Take the first segment if multiple numbers are provided
    s = s.split(RegExp(r'[;,/|·]')).first;
    final hasPlus = s.startsWith('+');
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return input.trim();
    return hasPlus ? '+$digits' : digits;
  }

  Future<void> _call(BuildContext context) async {
    final normalized = _normalize(phone);
    final uri = Uri(scheme: 'tel', path: normalized);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
      }
    } catch (e) {
      debugPrint('PhoneLink launch error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white);
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.phone_outlined, size: dense ? 16 : 18, color: Colors.white),
      const SizedBox(width: 4),
      Flexible(child: Text(phone, style: textStyle, overflow: TextOverflow.ellipsis, softWrap: false)),
    ]);

    // Avoid ripple/splash per design guidelines; use GestureDetector.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _call(context),
      child: content,
    );
  }
}
