import 'package:flutter/foundation.dart';

/// Best-effort helper to build a stable **web entry URI** (app root) from
/// [Uri.base], even when the current location includes an in-app route.
///
/// Why this exists:
/// - Dreamflow One-Click web deployments are hosted as a static site and do not
///   reliably support deep-link paths (e.g. `/auth/callback`).
/// - Supabase OAuth supports returning to the app root with `?code=...`, and the
///   Flutter router can forward that query to an internal callback route.
///
/// This function strips common first-level app routes from the current path,
/// preserving any hosting base prefix (e.g. Dreamflow Preview runs under a deep
/// path prefix).
Uri buildWebAppEntryUri(Uri base) {
  if (!kIsWeb) return base;

  // If we are already at root, keep it.
  if (base.path == '/' || base.path.isEmpty) {
    return base.replace(path: '/', queryParameters: const {}, fragment: '');
  }

  final segments = List<String>.from(base.pathSegments);
  const knownRoots = <String>{
    'auth',
    'onboarding',
    'conditions',
    'condition',
    'communities',
    'community',
    'group',
    'resources',
    'resource',
    'tracker',
    'messages',
    'profile',
    'achievements',
    'hub',
    'admin',
    'u',
  };

  int cutIndex = -1;
  for (var i = 0; i < segments.length; i++) {
    if (knownRoots.contains(segments[i])) {
      cutIndex = i;
      break;
    }
  }

  // If we didn't recognize a route segment, keep the existing path, but
  // normalize it to a directory-like prefix.
  final prefixSegments = cutIndex == -1 ? segments : segments.sublist(0, cutIndex);
  final prefixPath = prefixSegments.isEmpty ? '/' : '/${prefixSegments.join('/')}/';
  return base.replace(path: prefixPath, queryParameters: const {}, fragment: '');
}
