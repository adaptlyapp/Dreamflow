import 'package:flutter/material.dart';

/// BrandLogo renders the app logo from assets with optional rounded container.
///
/// Use `withContainer: true` for hero placements (Welcome/Sign-in) to provide
/// a themed background. For inline placements (app bars/section headers),
/// keep `withContainer: false`.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72, this.withContainer = false, this.radius});

  /// The square dimension of the logo area (width and height).
  final double size;

  /// Wrap the image in a rounded container with primaryContainer color.
  final bool withContainer;

  /// Optional custom radius for the container. Defaults to size/4 when null.
  final double? radius;

  static const String _assetPath = 'assets/images/adaptly_logo_2x.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedRadius = radius ?? size / 3;
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(withContainer ? resolvedRadius : 6),
      child: Image.asset(
        _assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to an icon if the asset isn't found for any reason.
          return Icon(Icons.image_not_supported_outlined, size: size * 0.9, color: cs.onSurfaceVariant);
        },
      ),
    );

    if (!withContainer) return img;

    return Container(
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(resolvedRadius),
        boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 18, spreadRadius: 2, offset: const Offset(0, 10))],
      ),
      child: SizedBox(width: size, height: size, child: img),
    );
  }
}
