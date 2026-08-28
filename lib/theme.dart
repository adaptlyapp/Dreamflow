import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// 🏥 ADAPTLY — HEALTHCARE-ORIENTED DESIGN SYSTEM
// =============================================================================
// 
// Professional healthcare aesthetic from adaptlyapp.com
// Clean, trustworthy, and accessible design with muted teal
// 
// 🎨 Core Brand Colors (from adaptlyapp.com):
//    - Primary Teal (#14B8A6) - Main brand color for buttons, icons, highlights
//    - Dark Teal (#0F766E) - Hover states, emphasis, darker accents
//    - Light Teal (#CCFBF1) - Background accents and subtle cards
//    - Bright Teal (#5EEAD4) - Success moments, highlights
// 
// 🤍 Light Mode Palette (65-70% white):
//    - White (#FFFFFF) - Main page background and cards
//    - Light Gray (#F8FAFC) - Alternate section backgrounds
//    - Border Gray (#E5E7EB) - Card and input borders
//    - Dark Slate (#1E293B) - Primary headings
//    - Slate Gray (#475569) - Body text
//    - Muted Gray (#94A3B8) - Secondary text and labels
// 
// 🖤 Dark Mode Surfaces (blue-tinted blacks):
//    - Obsidian (#0B0F14) - App background
//    - Slate (#111827) - Cards, sidebars
//    - Graphite (#1F2937) - Modals, raised panels
//    - Divider (#2A3441) - Borders, separators
// 
// 🔤 Typography: Inter (Professional, readable font)
//    Clean type scale for healthcare content:
//    - 34px/28px/22px (Headings) → Bold/Semibold
//    - 20px/17px/15px (Body) → Semibold/Regular  
//    - 13px (Captions) → Regular
// 
// 🧊 Glass UI Layer:
//    - Backdrop blur (14px) + subtle teal tint
//    - Gradient overlay with light teal
//    - Border: 1px solid rgba(255,255,255,0.06)
//    - Use GlassCard widget for major UI blocks
// 
// ✨ Teal Buttons:
//    - Solid color or subtle gradient
//    - Healthcare-friendly, accessible contrast
//    - Border radius: 10-14px
//    - Use FilledButton or ElevatedButton
// 
// 🚦 System Status Colors:
//    - Success: #14B8A6 (brand teal)
//    - Warning: #F59E0B (amber)
//    - Error: #EF4444 (red)
//    - Info: #3B82F6 (blue)
// 
// =============================================================================

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners (iOS 26 spec)
class AppRadius {
  static const double xs = 6.0;  // Small chips, badges
  static const double sm = 10.0; // iOS standard corner radius
  static const double md = 14.0; // Cards, buttons (iOS 26 default)
  static const double lg = 18.0; // Large cards, sheets
  static const double xl = 22.0; // Hero cards, modals
  static const double xxl = 28.0; // Full-screen modals
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

/// 🍏 Adaptly — Healthcare-Oriented Teal Design System (from adaptlyapp.com)
/// Professional healthcare aesthetic with muted teal, white, and slate tones
class LightModeColors {
  // Core Brand Colors - Adaptly Healthcare Teal (from adaptlyapp.com)
  static const adaptlyTeal = Color(0xFF14B8A6); // Primary teal - main brand color
  static const adaptlyDeep = Color(0xFF0F766E); // Dark teal - hover states, emphasis
  static const adaptlySoft = Color(0xFFCCFBF1); // Light teal - background accents
  static const adaptlyGlow = Color(0xFF5EEAD4); // Bright teal - success moments

  static const lightPrimary = adaptlyTeal;
  static const lightOnPrimary = Color(0xFFFFFFFF); // White text on teal
  static const lightPrimaryContainer = adaptlySoft; // Light teal background
  static const lightOnPrimaryContainer = adaptlyDeep;

  // Onboarding
  /// Light teal wash for onboarding slide backgrounds
  static const onboardingTealWash = adaptlySoft;

  static const lightSecondary = Color(0xFF475569); // Slate gray for secondary elements
  static const lightOnSecondary = Color(0xFFFFFFFF);

  static const lightTertiary = adaptlyGlow; // Bright teal for accents
  static const lightOnTertiary = Color(0xFF000000);

  // System Status Colors
  static const lightSuccess = Color(0xFF14B8A6); // Use brand teal for success
  static const lightWarning = Color(0xFFF59E0B);
  static const lightError = Color(0xFFEF4444);
  static const lightInfo = Color(0xFF3B82F6);
  
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFEE2E2);
  static const lightOnErrorContainer = Color(0xFF991B1B);

  static const lightSurface = Color(0xFFFFFFFF); // Pure white cards
  static const lightOnSurface = Color(0xFF1E293B); // Dark slate for headings
  static const lightBackground = Color(0xFFFFFFFF); // Pure white background for light mode
  static const lightSurfaceVariant = Color(0xFFF1F5F9); // Alternate light gray
  static const lightOnSurfaceVariant = Color(0xFF475569); // Slate gray for body text

  // Text colors from adaptlyapp.com
  static const textPrimary = Color(0xFF1E293B); // Dark slate - headings
  static const textSecondary = Color(0xFF475569); // Slate gray - body text
  static const textMuted = Color(0xFF94A3B8); // Muted gray - secondary text

  // Outline and shadow
  static const lightOutline = Color(0xFFE5E7EB); // Border gray
  static const lightShadow = Color(0xFF000000);
  static const lightInversePrimary = adaptlyTeal;
}

class DarkModeColors {
  // Core Brand Colors - Adaptly Healthcare Teal (matching light mode)
  static const adaptlyTeal = Color(0xFF14B8A6); // Primary teal
  static const adaptlyDeep = Color(0xFF0F766E); // Dark teal
  static const adaptlySoft = Color(0xFFCCFBF1); // Light teal
  static const adaptlyGlow = Color(0xFF5EEAD4); // Bright teal

  static const darkPrimary = adaptlyTeal;
  static const darkOnPrimary = Color(0xFFFFFFFF); // White text on teal
  static const darkPrimaryContainer = adaptlyDeep;
  static const darkOnPrimaryContainer = adaptlySoft;

  static const darkSecondary = Color(0xFF8E8E93); // iOS Grey
  static const darkOnSecondary = Color(0xFFFFFFFF);

  static const darkTertiary = adaptlyGlow; // Bright teal for accents
  static const darkOnTertiary = Color(0xFF000000);

  // System Status Colors (matching light mode)
  static const darkSuccess = Color(0xFF14B8A6); // Use brand teal for success
  static const darkWarning = Color(0xFFF59E0B);
  static const darkError = Color(0xFFEF4444);
  static const darkInfo = Color(0xFF3B82F6);

  static const darkOnError = Color(0xFFFFFFFF);
  static const darkErrorContainer = Color(0xFF7F1D1D);
  static const darkOnErrorContainer = Color(0xFFFEE2E2);

  // Apple glass surfaces (blue-tinted blacks)
  static const obsidian = Color(0xFF0B0F14); // App background (legacy)
  static const slate = Color(0xFF111827); // Cards, sidebars
  static const graphite = Color(0xFF1F2937); // Modals, raised panels
  static const divider = Color(0xFF2A3441); // Borders, separators

  static const darkSurface = Color(0xFF000000); // Pure black surfaces in dark mode
  static const darkOnSurface = Color(0xFFF9FAFB); // White Ice - headings
  static const darkSurfaceVariant = slate; // Cards
  static const darkOnSurfaceVariant = Color(0xFF9CA3AF); // Soft Gray - body text

  // Text hierarchy
  static const textPrimary = Color(0xFFF9FAFB); // White Ice - headings
  static const textSecondary = Color(0xFF9CA3AF); // Soft Gray - body
  static const textTertiary = Color(0xFF6B7280); // Muted Gray - labels

  // Outline and shadow
  static const darkOutline = Color(0xFF2A3441); // Divider
  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = adaptlyTeal;
  
  // Glass effect colors (for overlays)
  static const glassLight = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const glassBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const glassHighlight = Color(0x05FFFFFF); // rgba(255,255,255,0.02)
}

/// App-level helper gradients and glass effects
class AppGradients extends ThemeExtension<AppGradients> {
  final Gradient primaryGlow;
  final Gradient accentSheen;
  final Gradient glassGradient;
  final Gradient buttonGloss;
  final Gradient backgroundGlow;

  const AppGradients({
    required this.primaryGlow,
    required this.accentSheen,
    required this.glassGradient,
    required this.buttonGloss,
    required this.backgroundGlow,
  });

  @override
  AppGradients copyWith({
    Gradient? primaryGlow,
    Gradient? accentSheen,
    Gradient? glassGradient,
    Gradient? buttonGloss,
    Gradient? backgroundGlow,
  }) =>
      AppGradients(
        primaryGlow: primaryGlow ?? this.primaryGlow,
        accentSheen: accentSheen ?? this.accentSheen,
        glassGradient: glassGradient ?? this.glassGradient,
        buttonGloss: buttonGloss ?? this.buttonGloss,
        backgroundGlow: backgroundGlow ?? this.backgroundGlow,
      );

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return AppGradients(
      primaryGlow: Gradient.lerp(primaryGlow, other.primaryGlow, t)!,
      accentSheen: Gradient.lerp(accentSheen, other.accentSheen, t)!,
      glassGradient: Gradient.lerp(glassGradient, other.glassGradient, t)!,
      buttonGloss: Gradient.lerp(buttonGloss, other.buttonGloss, t)!,
      backgroundGlow: Gradient.lerp(backgroundGlow, other.backgroundGlow, t)!,
    );
  }
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with modern, neutral aesthetic
ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: LightModeColors.lightPrimary,
        onPrimary: LightModeColors.lightOnPrimary,
        primaryContainer: LightModeColors.lightPrimaryContainer,
        onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
        secondary: LightModeColors.lightSecondary,
        onSecondary: LightModeColors.lightOnSecondary,
        tertiary: LightModeColors.lightTertiary,
        onTertiary: LightModeColors.lightOnTertiary,
        error: LightModeColors.lightError,
        onError: LightModeColors.lightOnError,
        errorContainer: LightModeColors.lightErrorContainer,
        onErrorContainer: LightModeColors.lightOnErrorContainer,
        surface: LightModeColors.lightSurface,
        onSurface: LightModeColors.lightOnSurface,
        surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
        onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
        outline: LightModeColors.lightOutline,
        shadow: LightModeColors.lightShadow,
        inversePrimary: LightModeColors.lightInversePrimary,
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightModeColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: LightModeColors.lightSurface,
        foregroundColor: LightModeColors.lightOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: LightModeColors.lightOutline.withValues(alpha: 0.1),
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: LightModeColors.lightOnSurface,
          letterSpacing: -0.17,
        ),
      ),
      iconTheme: const IconThemeData(color: LightModeColors.lightPrimary, size: 22),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const MaterialStatePropertyAll(LightModeColors.lightPrimary),
          overlayColor: MaterialStatePropertyAll(LightModeColors.lightPrimary.withValues(alpha: 0.1)),
          padding: const MaterialStatePropertyAll(EdgeInsets.all(8)),
          minimumSize: const MaterialStatePropertyAll(Size(44, 44)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const MaterialStatePropertyAll(CircleBorder()),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              const MaterialStatePropertyAll(LightModeColors.lightPrimary),
          foregroundColor:
              const MaterialStatePropertyAll(LightModeColors.lightOnPrimary),
          overlayColor: MaterialStatePropertyAll(
              LightModeColors.lightOnPrimary.withValues(alpha: 0.12)),
          elevation: const MaterialStatePropertyAll(0),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          // Keep light mode buttons neutral so text stays black on white
          foregroundColor: const MaterialStatePropertyAll(Colors.black),
          overlayColor: MaterialStatePropertyAll(const Color(0x14000000)),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          // Outlined buttons stay monochrome in light mode
          foregroundColor: const MaterialStatePropertyAll(Colors.black),
          side: MaterialStatePropertyAll(BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.4), width: 1)),
          overlayColor: const MaterialStatePropertyAll(Color(0x14000000)),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              const MaterialStatePropertyAll(LightModeColors.lightPrimary),
          foregroundColor:
              const MaterialStatePropertyAll(LightModeColors.lightOnPrimary),
          overlayColor: MaterialStatePropertyAll(
              LightModeColors.lightOnPrimary.withValues(alpha: 0.12)),
          elevation: const MaterialStatePropertyAll(0),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LightModeColors.lightPrimary,
        foregroundColor: LightModeColors.lightOnPrimary,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 8,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: LightModeColors.lightSurface.withValues(alpha: 0.95),
        selectedItemColor: LightModeColors.lightPrimary,
        unselectedItemColor: LightModeColors.lightSecondary,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        elevation: 0,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: LightModeColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: LightModeColors.lightOutline.withValues(alpha: 0.12),
            width: 0.33,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: LightModeColors.lightSecondary,
        textColor: LightModeColors.lightOnSurface,
        selectedColor: LightModeColors.lightPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minLeadingWidth: 40,
        minVerticalPadding: 8,
        visualDensity: VisualDensity.comfortable,
      ),
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.inter(color: LightModeColors.lightOnSurface, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.24),
        backgroundColor: LightModeColors.lightSurfaceVariant,
        selectedColor: LightModeColors.lightPrimary.withValues(alpha: 0.15),
        side: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.20), width: 0.33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
        pressElevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        labelColor: LightModeColors.lightPrimary,
        unselectedLabelColor: LightModeColors.lightSecondary,
        indicatorColor: LightModeColors.lightPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: LightModeColors.lightOutline.withValues(alpha: 0.3),
        dividerHeight: 0.5,
      ),
      dividerTheme: DividerThemeData(
        color: LightModeColors.lightOutline.withValues(alpha: 0.20),
        thickness: 0.5,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.15),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3C3C43).withValues(alpha: 0.95),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LightModeColors.lightSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIconColor: LightModeColors.lightSecondary,
        suffixIconColor: LightModeColors.lightSecondary,
        hintStyle:
            GoogleFonts.inter(color: LightModeColors.lightSecondary, fontSize: 17, letterSpacing: -0.17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: LightModeColors.lightOutline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: LightModeColors.lightOutline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: LightModeColors.lightPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: LightModeColors.lightError,
            width: 0.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: LightModeColors.lightError,
            width: 1.5,
          ),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: LightModeColors.lightOnSurface,
        selectionColor: Color(0x14333333),
        selectionHandleColor: LightModeColors.lightOnSurface,
      ),
      textTheme: _buildTextTheme(Brightness.light)
          .apply(bodyColor: Colors.black, displayColor: Colors.black),
      extensions: const [
        AppGradients(
          primaryGlow: LinearGradient(
            colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accentSheen: LinearGradient(
            colors: [Color(0xFFCCFBF1), Color(0xFF14B8A6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          glassGradient: LinearGradient(
            colors: [Color(0xFF14B8A6), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          buttonGloss: LinearGradient(
            colors: [Color(0xFF5EEAD4), Color(0xFF14B8A6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          backgroundGlow: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF0F766E), Color(0xFFF8FAFC)],
          ),
        ),
      ],
    );

/// Dark theme with good contrast and readability
ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: DarkModeColors.darkPrimary,
        onPrimary: DarkModeColors.darkOnPrimary,
        primaryContainer: DarkModeColors.darkPrimaryContainer,
        onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
        secondary: DarkModeColors.darkSecondary,
        onSecondary: DarkModeColors.darkOnSecondary,
        tertiary: DarkModeColors.darkTertiary,
        onTertiary: DarkModeColors.darkOnTertiary,
        error: DarkModeColors.darkError,
        onError: DarkModeColors.darkOnError,
        errorContainer: DarkModeColors.darkErrorContainer,
        onErrorContainer: DarkModeColors.darkOnErrorContainer,
        surface: DarkModeColors.darkSurface,
        onSurface: DarkModeColors.darkOnSurface,
        surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
        onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
        outline: DarkModeColors.darkOutline,
        shadow: DarkModeColors.darkShadow,
        inversePrimary: DarkModeColors.darkInversePrimary,
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkModeColors.darkSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: DarkModeColors.darkSurface,
        foregroundColor: DarkModeColors.darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: DarkModeColors.darkOnSurface),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: DarkModeColors.darkOnSurface,
          letterSpacing: -0.17,
        ),
      ),
      iconTheme: const IconThemeData(color: DarkModeColors.darkPrimary, size: 22),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const MaterialStatePropertyAll(DarkModeColors.darkPrimary),
          overlayColor: MaterialStatePropertyAll(DarkModeColors.darkPrimary.withValues(alpha: 0.15)),
          padding: const MaterialStatePropertyAll(EdgeInsets.all(8)),
          minimumSize: const MaterialStatePropertyAll(Size(44, 44)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const MaterialStatePropertyAll(CircleBorder()),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Color(0x33FFFFFF),
        selectionHandleColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              const MaterialStatePropertyAll(DarkModeColors.darkPrimary),
          foregroundColor:
              const MaterialStatePropertyAll(DarkModeColors.darkOnPrimary),
          overlayColor: MaterialStatePropertyAll(
              Colors.white.withValues(alpha: 0.15)),
          elevation: const MaterialStatePropertyAll(8),
          shadowColor: MaterialStatePropertyAll(DarkModeColors.darkPrimary.withValues(alpha: 0.5)),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const MaterialStatePropertyAll(DarkModeColors.darkPrimary),
          overlayColor: MaterialStatePropertyAll(DarkModeColors.darkPrimary.withValues(alpha: 0.12)),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const MaterialStatePropertyAll(DarkModeColors.darkPrimary),
          side: MaterialStatePropertyAll(BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.6), width: 1)),
          overlayColor: MaterialStatePropertyAll(DarkModeColors.darkPrimary.withValues(alpha: 0.12)),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              const MaterialStatePropertyAll(DarkModeColors.darkPrimary),
          foregroundColor:
              const MaterialStatePropertyAll(DarkModeColors.darkOnPrimary),
          overlayColor: MaterialStatePropertyAll(
              Colors.white.withValues(alpha: 0.15)),
          elevation: const MaterialStatePropertyAll(8),
          shadowColor: MaterialStatePropertyAll(DarkModeColors.darkPrimary.withValues(alpha: 0.5)),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          ),
          textStyle: MaterialStatePropertyAll(
            GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.17),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: DarkModeColors.darkPrimary,
        foregroundColor: Colors.white,
        elevation: 8,
        focusElevation: 12,
        hoverElevation: 12,
        highlightElevation: 16,
        shape: const CircleBorder(),
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 56),
        extendedIconLabelSpacing: 12,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: DarkModeColors.darkSurface.withValues(alpha: 0.95),
        selectedItemColor: DarkModeColors.darkPrimary,
        unselectedItemColor: DarkModeColors.darkSecondary,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        elevation: 0,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        color: DarkModeColors.darkSurfaceVariant,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: DarkModeColors.glassBorder.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: DarkModeColors.darkSecondary,
        textColor: DarkModeColors.darkOnSurface,
        selectedColor: DarkModeColors.darkPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minLeadingWidth: 40,
        minVerticalPadding: 8,
        visualDensity: VisualDensity.comfortable,
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.15),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3C3C43).withValues(alpha: 0.95),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.24),
        backgroundColor: DarkModeColors.darkSurfaceVariant,
        selectedColor: DarkModeColors.darkPrimary.withValues(alpha: 0.25),
        side: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.25), width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
        pressElevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08),
        labelColor: DarkModeColors.darkPrimary,
        unselectedLabelColor: DarkModeColors.darkSecondary,
        indicatorColor: DarkModeColors.darkPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: DarkModeColors.darkOutline.withValues(alpha: 0.6),
        dividerHeight: 0.5,
      ),
      dividerTheme: DividerThemeData(
        color: DarkModeColors.darkOutline.withValues(alpha: 0.30),
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkModeColors.darkSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIconColor: DarkModeColors.darkSecondary,
        suffixIconColor: DarkModeColors.darkSecondary,
        hintStyle:
            GoogleFonts.inter(color: DarkModeColors.darkSecondary, fontSize: 17, letterSpacing: -0.17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: DarkModeColors.darkOutline.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: DarkModeColors.darkOutline.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: DarkModeColors.darkPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: DarkModeColors.darkError,
            width: 0.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: DarkModeColors.darkError,
            width: 1.5,
          ),
        ),
      ),
      textTheme: _buildTextTheme(Brightness.dark)
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      extensions: const [
        AppGradients(
          primaryGlow: LinearGradient(
            colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accentSheen: LinearGradient(
            colors: [Color(0xFFCCFBF1), Color(0xFF14B8A6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          glassGradient: LinearGradient(
            colors: [Color(0x1414B8A6), Color(0xD9111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          buttonGloss: LinearGradient(
            colors: [Color(0xFF5EEAD4), Color(0xFF14B8A6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          backgroundGlow: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF0F766E), Color(0xFF020617)],
          ),
        ),
      ],
    );

/// **Themed Background Image Widget** — Displays dark/light mode backgrounds
/// 
/// Returns the appropriate background image based on current theme
class ThemedBackgroundImage extends StatelessWidget {
  const ThemedBackgroundImage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Image.asset(
        isDarkMode
            ? 'assets/images/ChatGPT_Image_Jul_13_2026_08_13_46_AM_1.png'
            : 'assets/images/image-gen-1_6.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

/// **Glossy Scaffold** — Adds themed background image to any screen
/// 
/// Use this instead of regular Scaffold to get automatic light/dark mode backgrounds
class GlassyScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool useFamilyBackground;
  final bool useThemedBackground;
  final bool? resizeToAvoidBottomInset;

  const GlassyScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.useFamilyBackground = false,
    this.useThemedBackground = true,
    this.resizeToAvoidBottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: useThemedBackground && appBar != null,
      appBar: appBar,
      body: useThemedBackground
          ? Stack(
              fit: StackFit.expand,
              children: [
                const ThemedBackgroundImage(),
                if (body != null) body!,
              ],
            )
          : body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor ?? (useThemedBackground ? Colors.black : null),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// Build text theme using SF Pro on iOS/macOS, Inter elsewhere
/// 
/// SF Pro is Apple's native system font - using it gives authentic iOS feel
/// On non-Apple platforms, we use Inter as a fallback (nearly identical metrics)
/// 
/// Matches Apple's exact typography scale from iOS 17
TextTheme _buildTextTheme(Brightness brightness) {
  final baseStyle = _getBaseTextStyle();
  
  return TextTheme(
    // Large Title (34px, Bold)
    displayLarge: baseStyle.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.34,
      height: 1.2,
    ),
    // Title 1 (28px, Bold)
    displayMedium: baseStyle.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.28,
      height: 1.25,
    ),
    // Title 2 (22px, Bold)
    displaySmall: baseStyle.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.22,
      height: 1.3,
    ),
    // Large Title (34px, Bold)
    headlineLarge: baseStyle.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.34,
      height: 1.2,
    ),
    // Title 1 (28px, Semibold)
    headlineMedium: baseStyle.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.28,
      height: 1.25,
    ),
    // Title 2 (22px, Semibold)
    headlineSmall: baseStyle.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.22,
      height: 1.3,
    ),
    // Title 3 (20px, Semibold)
    titleLarge: baseStyle.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.20,
      height: 1.3,
    ),
    // Headline (17px, Semibold)
    titleMedium: baseStyle.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.17,
      height: 1.35,
    ),
    // Subhead (15px, Semibold)
    titleSmall: baseStyle.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
      height: 1.4,
    ),
    // Body (17px, Regular)
    labelLarge: baseStyle.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.17,
      height: 1.35,
    ),
    // Callout (16px, Regular)  
    labelMedium: baseStyle.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.16,
      height: 1.4,
    ),
    // Footnote (13px, Regular)
    labelSmall: baseStyle.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 1.45,
    ),
    // Body (17px, Regular)
    bodyLarge: baseStyle.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.17,
      height: 1.5,
    ),
    // Subhead (15px, Regular)
    bodyMedium: baseStyle.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.15,
      height: 1.5,
    ),
    // Footnote (13px, Regular)
    bodySmall: baseStyle.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 1.45,
    ),
  );
}

/// Returns SF Pro on iOS/macOS, Inter on all other platforms
TextStyle _getBaseTextStyle() {
  // Use SF Pro on Apple platforms (iOS, macOS)
  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    return const TextStyle(fontFamily: '.SF Pro Text');
  }
  
  // Use Inter on all other platforms (Android, Web, Windows, Linux)
  return GoogleFonts.inter();
}
