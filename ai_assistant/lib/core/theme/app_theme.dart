import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const Color primary = Color(0xFF0071E3);
  static const Color primaryLight = Color(0xFFE8F2FD);
  static const Color scaffoldBg = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textTertiary = Color(0xFFAEAEB2);
  static const Color border = Color(0xFFE5E5EA);
  static const Color danger = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color purple = Color(0xFFAF52DE);
  static const Color checkboxBorder = Color(0xFFC7C7CC);
  static const Color inputBg = Color(0xFFF9F9FB);
  static const Color chipBg = Color(0xFFF0F0F5);
  static const Color chipText = Color(0xFF636366);
  static const Color handleBar = Color(0xFFD1D1D6);
  static const Color billBg = Color(0xFFFCE4EC);
  static const Color billText = Color(0xFFE91E63);
  static const Color workBg = Color(0xFFE8F2FD);
  static const Color personalBg = Color(0xFFF3E8FF);
  static const Color healthBg = Color(0xFFE8FAF3);
  static const Color healthText = Color(0xFF1ABC9C);
  static const Color calendarBg = Color(0xFFF0E6FF);
  static const Color calendarText = Color(0xFF7C3AED);
  static const Color messageBg = Color(0xFFEAF5EA);
  static const Color routineBg = Color(0xFFFEF3E0);
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientEnd = Color(0xFF764BA2);
}

class AppAnimations {
  static const Duration shortDuration = Duration(milliseconds: 150);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 450);

  static const Curve springCurve = Curves.easeOut;
  static const Curve springBackCurve = Curves.elasticOut;
  static const Curve slideCurve = Curves.easeOutCubic;

  static List<BoxShadow> layeredShadow({double opacity = 0.08}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity * 0.3),
        blurRadius: 1,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity * 0.7),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> cardShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> elevatedShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primary,
        onSecondary: Colors.white,
        surface: AppColors.scaffoldBg,
        onSurface: AppColors.text,
        surfaceContainerHighest: AppColors.border,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.handleBar,
        error: AppColors.danger,
        onError: Colors.white,
        shadow: Color(0x1F000000),
      ),
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.text,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 56,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 20);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 20);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        shadowColor: const Color(0x0F000000),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        displayMedium: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        displaySmall: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        titleLarge: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        titleMedium: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
        titleSmall: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        bodySmall: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        labelLarge: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
        labelMedium: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.chipBg,
        selectedColor: AppColors.primaryLight,
        labelStyle: const TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.chipText,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 4,
        highlightElevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minLeadingWidth: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1D1D1F),
      ),
    );
  }
}
