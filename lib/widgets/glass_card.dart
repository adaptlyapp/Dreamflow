import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wellspring/theme.dart';

/// **Adaptive Premium Card** — Neumorphic (light) / Glass (dark)
/// 
/// Light Mode: Soft neumorphic shadows with depth
/// Dark Mode: Apple Vision Pro glass blur effect
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool showGlow;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 30,
    this.showGlow = false,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradients = Theme.of(context).extension<AppGradients>();

    if (!isDark) {
      // ✨ NEUMORPHIC LIGHT MODE — Soft shadows, embossed look
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: widget.margin ?? EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _isHovered
                ? [
                    // Hover state — softer, lifted shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    // Neumorphic shadows — light top-left, dark bottom-right
                    BoxShadow(
                      color: const Color(0xFFBEBEBE), // Dark shadow
                      blurRadius: 30,
                      offset: const Offset(15, 15),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white, // Light shadow
                      blurRadius: 30,
                      offset: const Offset(-15, -15),
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Padding(
                  padding: widget.padding ?? AppSpacing.paddingMd,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 🌙 GLASS DARK MODE — Vision Pro style
    final glowShadows = widget.showGlow
        ? [
            BoxShadow(
              color: DarkModeColors.darkPrimary.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ]
        : <BoxShadow>[];

    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: DarkModeColors.glassHighlight,
            blurRadius: 0,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 20),
          ),
          ...glowShadows,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradients?.glassGradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: DarkModeColors.glassBorder,
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Light sweep effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        // Use multiple stops to avoid visible banding/"stripe" artifacts
                        // on some Web/CanvasKit render paths.
                        colors: [
                          DarkModeColors.glassHighlight,
                          DarkModeColors.glassLight,
                          DarkModeColors.glassHighlight,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.28, 0.62, 1.0],
                        tileMode: TileMode.clamp,
                      ),
                    ),
                  ),
                ),
                // Content
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Padding(
                      padding: widget.padding ?? AppSpacing.paddingMd,
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// **Neumorphic Content Card** — Full CSS-style card with gradient header
/// 
/// Matches the Uiverse.io design with:
/// - Gradient image header
/// - Save/bookmark button
/// - Text section
/// - Icon box with teal accent
class NeumorphicContentCard extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final String? badgeText;
  final IconData? badgeIcon;
  final Widget? headerChild;
  final List<Color>? gradientColors;
  final bool isSaved;
  final VoidCallback? onSavePressed;
  final VoidCallback? onTap;

  const NeumorphicContentCard({
    super.key,
    this.title,
    this.subtitle,
    this.badgeText,
    this.badgeIcon,
    this.headerChild,
    this.gradientColors,
    this.isSaved = false,
    this.onSavePressed,
    this.onTap,
  });

  @override
  State<NeumorphicContentCard> createState() => _NeumorphicContentCardState();
}

class _NeumorphicContentCardState extends State<NeumorphicContentCard> {
  bool _isHovered = false;
  bool _isSaveHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    
    final defaultGradient = [
      const Color(0xFFE66465),
      const Color(0xFF9198E5),
    ];
    final gradient = widget.gradientColors ?? defaultGradient;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 252,
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainer : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(10, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFBEBEBE),
                        blurRadius: 30,
                        offset: const Offset(15, 15),
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 30,
                        offset: Offset(-15, -15),
                      ),
                    ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gradient header with save button
                  Container(
                    height: 132,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (widget.headerChild != null)
                          Center(child: widget.headerChild),
                        // Save button
                        if (widget.onSavePressed != null)
                          Positioned(
                            top: 20,
                            right: 20,
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _isSaveHovered = true),
                              onExit: (_) => setState(() => _isSaveHovered = false),
                              child: GestureDetector(
                                onTap: widget.onSavePressed,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  transform: _isSaveHovered
                                      ? (Matrix4.identity()
                                        ..scale(1.1)
                                        ..rotateZ(0.17))
                                      : Matrix4.identity(),
                                  transformAlignment: Alignment.center,
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    size: 15,
                                    color: _isSaveHovered || widget.isSaved
                                        ? cs.primary
                                        : const Color(0xFFCED8DE),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Text content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title != null)
                          Text(
                            widget.title!,
                            style: context.textStyles.titleSmall?.semiBold.copyWith(
                              color: isDark ? cs.onSurface : Colors.black,
                            ),
                          ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: context.textStyles.bodySmall?.copyWith(
                              color: isDark 
                                  ? cs.onSurfaceVariant 
                                  : const Color(0xFF999999),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (widget.badgeText != null) ...[
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? cs.primary.withValues(alpha: 0.15)
                                  : const Color(0xFFE3FFF9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.badgeIcon != null)
                                  Icon(
                                    widget.badgeIcon,
                                    size: 17,
                                    color: cs.primary,
                                  ),
                                if (widget.badgeIcon != null)
                                  const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    widget.badgeText!,
                                    style: context.textStyles.bodySmall?.semiBold.copyWith(
                                      color: isDark
                                          ? cs.primary
                                          : const Color(0xFF9198E5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// **Glossy Button** — Apple Wallet wet button style
/// 
/// Features:
/// - Gradient fill (light to dark)
/// - Inset highlight on top edge
/// - Glowing shadow
class GlossButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlossButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradients = Theme.of(context).extension<AppGradients>();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradients?.buttonGloss,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: DarkModeColors.darkPrimary.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// **Neon Glow Widget** — Apple Watch ring style
/// 
/// Wraps any widget with a teal neon glow
class NeonGlow extends StatelessWidget {
  final Widget child;
  final double glowRadius;
  final Color? glowColor;

  const NeonGlow({
    super.key,
    required this.child,
    this.glowRadius = 12,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = glowColor ?? DarkModeColors.darkPrimary;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.7),
            blurRadius: glowRadius,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// **Soft Neumorphic Button** — Pressed/unpressed states
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double size;
  final double borderRadius;
  final bool isActive;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.size = 50,
    this.borderRadius = 15,
    this.isActive = false,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final isPressed = _isPressed || widget.isActive;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainer : Colors.white,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: isPressed
              ? [
                  // Inset shadow effect
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0xFFBEBEBE),
                    blurRadius: 5,
                    offset: const Offset(2, 2),
                  ),
                ]
              : isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(5, 5),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFBEBEBE),
                        blurRadius: 15,
                        offset: const Offset(5, 5),
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 15,
                        offset: Offset(-5, -5),
                      ),
                    ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

/// **Neumorphic Text Field** — Soft inset input
class NeumorphicTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const NeumorphicTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(3, 3),
                ),
              ]
            : [
                // Inner shadow effect (simulated)
                BoxShadow(
                  color: const Color(0xFFBEBEBE),
                  blurRadius: 10,
                  offset: const Offset(3, 3),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 10,
                  offset: Offset(-3, -3),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? cs.onSurfaceVariant : const Color(0xFF999999),
          ),
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color: isDark ? cs.onSurfaceVariant : const Color(0xFF999999),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
