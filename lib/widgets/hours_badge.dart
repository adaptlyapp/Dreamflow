import 'package:flutter/material.dart';
import 'package:wellspring/theme.dart';

/// Displays business hours in a compact, stylish way.
///
/// Accepts a raw `availability` string from the Resource model, which may be:
/// - "Open now" | "Closed now" | "Hours not available" (Google)
/// - "24/7" or an OpenStreetMap opening_hours expression (e.g., "Mo-Fr 08:00-18:00; Sa 09:00-14:00")
///
/// The widget prettifies common patterns and shows a colored status chip
/// when possible, followed by a condensed weekly summary.
class HoursBadge extends StatelessWidget {
  final String availability;
  final bool dense;
  const HoursBadge({super.key, required this.availability, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parsed = _HoursParser(availability).parse();

    final chipBg = parsed.status == _Status.open
        ? cs.primaryContainer
        : parsed.status == _Status.closed
            ? cs.errorContainer
            : cs.surfaceContainerHighest;
    final chipFg = parsed.status == _Status.open
        ? cs.onPrimaryContainer
        : parsed.status == _Status.closed
            ? cs.onErrorContainer
            : cs.onSurfaceVariant;

    final label = parsed.statusLabel;

    return LayoutBuilder(builder: (context, constraints) {
      // Use Wrap so the summary can move to the next line on narrow cards
      // preventing horizontal overflow. Limit summary to 2 lines with ellipsis.
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Status chip
          Container(
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(999)),
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: dense ? 2 : 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule, size: dense ? 12 : 14, color: chipFg),
              SizedBox(width: 4),
              Text(label, style: (dense ? context.textStyles.labelSmall : context.textStyles.labelMedium)?.withColor(chipFg)),
            ]),
          ),
          if (parsed.summary != null && parsed.summary!.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Text(
                parsed.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                softWrap: true,
              ),
            ),
        ],
      );
    });
  }
}

enum _Status { open, closed, unknown }

class _ParsedHours {
  final _Status status;
  final String statusLabel;
  final String? summary; // e.g., "Mon–Fri 8 AM–6 PM • Sat 9 AM–2 PM" or "24/7"
  _ParsedHours({required this.status, required this.statusLabel, this.summary});
}

class _HoursParser {
  final String raw;
  _HoursParser(this.raw);

  _ParsedHours parse() {
    final t = raw.trim();
    if (t.isEmpty) return _ParsedHours(status: _Status.unknown, statusLabel: 'Hours not available');

    // Simple Google statuses
    if (_equalsIgnoreCase(t, 'Open now')) {
      return _ParsedHours(status: _Status.open, statusLabel: 'Open now');
    }
    if (_equalsIgnoreCase(t, 'Closed now')) {
      return _ParsedHours(status: _Status.closed, statusLabel: 'Closed now');
    }
    if (_equalsIgnoreCase(t, 'Hours not available')) {
      return _ParsedHours(status: _Status.unknown, statusLabel: 'Hours not available');
    }

    // Common 24/7 indicator
    if (t.contains('24/7')) {
      return _ParsedHours(status: _Status.open, statusLabel: 'Open', summary: 'Open 24/7');
    }

    // Try to prettify OSM-like opening_hours expressions.
    final pretty = _prettifyOpeningHours(t);
    if (pretty != null && pretty.isNotEmpty) {
      return _ParsedHours(status: _Status.unknown, statusLabel: 'Hours', summary: pretty);
    }

    // Fallback: show raw but label nicely
    return _ParsedHours(status: _Status.unknown, statusLabel: 'Hours', summary: t);
  }

  bool _equalsIgnoreCase(String a, String b) => a.toLowerCase() == b.toLowerCase();

  // Converts a typical OSM opening_hours string into a compact human-friendly summary.
  // Examples:
  //  - "Mo-Fr 08:00-18:00; Sa 09:00-14:00" -> "Mon–Fri 8 AM–6 PM • Sat 9 AM–2 PM"
  //  - "Mo,We,Fr 10:00-16:00" -> "Mon, Wed, Fri 10 AM–4 PM"
  String? _prettifyOpeningHours(String s) {
    try {
      final parts = s.split(';').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) return null;
      final prettyParts = <String>[];
      for (final seg in parts) {
        final pp = _prettifySegment(seg);
        if (pp != null && pp.isNotEmpty) prettyParts.add(pp);
      }
      if (prettyParts.isEmpty) return null;
      // Keep to two segments to remain compact
      final limited = prettyParts.take(2).toList();
      return limited.join(' • ');
    } catch (_) {
      return null;
    }
  }

  String? _prettifySegment(String seg) {
    // Split leading day tokens and trailing time ranges
    // Heuristic: find first digit, everything before = days, after = time pattern
    final idx = seg.indexOf(RegExp(r"[0-9]"));
    String daysPart;
    String timePart;
    if (idx == -1) {
      // No times, maybe "Su off" etc.
      daysPart = seg;
      timePart = '';
    } else {
      daysPart = seg.substring(0, idx).trim();
      timePart = seg.substring(idx).trim();
    }

    if (daysPart.isEmpty && timePart.isEmpty) return null;

    final daysPretty = _prettifyDays(daysPart);
    final timesPretty = _prettifyTimes(timePart);

    if (timesPretty == null || timesPretty.isEmpty) {
      // No valid time ranges; show only days if useful
      return daysPretty.isNotEmpty ? daysPretty : null;
    }
    if (daysPretty.isEmpty) return timesPretty;
    return '$daysPretty $timesPretty';
  }

  String _prettifyDays(String s) {
    if (s.isEmpty) return '';
    // Normalize tokens like "Mo-Fr", "Mo,We,Fr"
    s = s.replaceAll('PH', '').trim(); // ignore public holiday tokens for summary
    if (s.isEmpty) return '';

    final tokens = s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final pretty = <String>[];
    for (final t in tokens) {
      if (t.contains('-')) {
        final range = t.split('-');
        if (range.length == 2) {
          final a = _dayFull(range[0]);
          final b = _dayFull(range[1]);
          if (a.isNotEmpty && b.isNotEmpty) {
            pretty.add('$a–$b');
            continue;
          }
        }
      }
      final d = _dayFull(t);
      if (d.isNotEmpty) pretty.add(d);
    }
    return pretty.join(', ');
  }

  String _dayFull(String abbr) {
    final key = abbr.trim().substring(0, abbr.trim().length.clamp(0, 2)).toLowerCase();
    switch (key) {
      case 'mo':
        return 'Mon';
      case 'tu':
        return 'Tue';
      case 'we':
        return 'Wed';
      case 'th':
        return 'Thu';
      case 'fr':
        return 'Fri';
      case 'sa':
        return 'Sat';
      case 'su':
        return 'Sun';
      default:
        return '';
    }
  }

  String? _prettifyTimes(String s) {
    if (s.isEmpty) return null;
    // Support multiple ranges separated by commas: "08:00-12:00,13:00-18:00"
    final ranges = s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final pretty = <String>[];
    for (final r in ranges) {
      final m = RegExp(r'^(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').firstMatch(r);
      if (m != null) {
        final start = m.group(1)!;
        final end = m.group(2)!;
        pretty.add('${_hmToAmPm(start)}–${_hmToAmPm(end)}');
      }
    }
    if (pretty.isEmpty) return null;
    return pretty.join(', ');
  }

  String _hmToAmPm(String hm) {
    // "08:00" -> "8 AM", "14:30" -> "2:30 PM"
    final parts = hm.split(':');
    int h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final suffix = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    final mStr = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
    return '$h$mStr $suffix';
  }
}
