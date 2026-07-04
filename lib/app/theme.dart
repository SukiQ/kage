import 'package:flutter/material.dart';

import '../shared/theme/kage_tokens.dart';

/// Kage 主题：简约扁平现代 —— 中性白/黑 + 现代灰阶为底，
/// 点缀色（primary）随当前角色切换为火影五影主题色，全局 MiSans，圆润（radius≈16）。
class KageTheme {
  KageTheme._();

  static const String fontMain = 'MiSans';

  /// 火影橙黄固定点缀色（不再随角色切换）。
  static const Color accent = Color(0xFFB91C1C);
  static const Color onAccent = Color(0xFFFFFFFF);

  static ThemeData get light => _build(_scheme(true), KageDesignTokens.light);

  static ThemeData get dark => _build(_scheme(false), KageDesignTokens.dark);

  // 中性灰阶底 + 火影橙黄 primary
  static ColorScheme _scheme(bool light) {
    const accent = KageTheme.accent;
    // 全局底色统一：所有 surface* 同色（消除多层级灰拼色），
    // 仅 surfaceContainerHighest 保留微对比给 AI 聊天气泡。
    final base = light ? const Color(0xFFFFFFFF) : const Color(0xFF141619);
    final bubble = light ? const Color(0xFFF4F4F6) : const Color(0xFF1E2126);
    return ColorScheme(
      brightness: light ? Brightness.light : Brightness.dark,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: accent.withValues(alpha: 0.16),
      onPrimaryContainer: light
          ? const Color(0xFFB45309)
          : const Color(0xFFFFB020),
      secondary: light ? const Color(0xFF6B7178) : const Color(0xFF9AA0A8),
      onSecondary: light ? const Color(0xFFFFFFFF) : const Color(0xFF141619),
      secondaryContainer: light
          ? const Color(0xFFE8E8EC)
          : const Color(0xFF2D323A),
      onSecondaryContainer: light
          ? const Color(0xFF1A1D21)
          : const Color(0xFFE6E8EC),
      tertiary: accent,
      onTertiary: onAccent,
      error: light ? const Color(0xFFD92D20) : const Color(0xFFFF6B6B),
      onError: light ? const Color(0xFFFFFFFF) : const Color(0xFF1A0A0A),
      errorContainer: light ? const Color(0xFFFDECEB) : const Color(0xFF3A1A1A),
      onErrorContainer: light
          ? const Color(0xFF7A1A12)
          : const Color(0xFFFFD2D0),
      surface: base,
      onSurface: light ? const Color(0xFF1A1D21) : const Color(0xFFE6E8EC),
      surfaceContainerLowest: base,
      surfaceContainerLow: base,
      surfaceContainer: base,
      surfaceContainerHigh: base,
      surfaceContainerHighest: bubble,
      onSurfaceVariant: light
          ? const Color(0xFF6B7178)
          : const Color(0xFF9AA0A8),
      outline: light ? const Color(0xFFE2E2E6) : const Color(0xFF2C3036),
      outlineVariant: light ? const Color(0xFFEFEFF2) : const Color(0xFF23262B),
      shadow: Colors.transparent,
      scrim: light ? const Color(0x66000000) : const Color(0xCC000000),
      inverseSurface: light ? const Color(0xFF1A1D21) : const Color(0xFFE6E8EC),
      onInverseSurface: light
          ? const Color(0xFFE6E8EC)
          : const Color(0xFF1A1D21),
      inversePrimary: accent.withValues(alpha: 0.5),
      surfaceTint: Colors.transparent,
    );
  }

  static TextTheme _textTheme(ColorScheme cs) {
    final base = ThemeData(brightness: cs.brightness).textTheme;
    return base
        .apply(fontFamily: fontMain)
        .copyWith(
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        );
  }

  static ThemeData _build(ColorScheme cs, KageDesignTokens tok) {
    final tt = _textTheme(cs);
    final rCard = BorderRadius.circular(tok.radius);
    final rBtn = BorderRadius.circular(tok.radiusButton);
    final rChip = BorderRadius.circular(tok.radiusChip);
    final rSmall = BorderRadius.circular(tok.radiusSmall);
    final outlineSide = BorderSide(color: cs.outline, width: tok.borderWidth);
    final outlineVariantSide = BorderSide(
      color: cs.outlineVariant,
      width: tok.borderWidth,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: cs.brightness,
      colorScheme: cs,
      fontFamily: fontMain,
      textTheme: tt,
      primaryTextTheme: tt,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: cs.surfaceContainerLow,
      extensions: <ThemeExtension<dynamic>>[tok],

      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: rCard),
        margin: EdgeInsets.zero,
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        foregroundColor: cs.onSurface,
        titleTextStyle: tt.titleSmall ?? TextStyle(color: cs.onSurface),
        toolbarHeight: 48,
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: rBtn, borderSide: outlineSide),
        enabledBorder: OutlineInputBorder(
          borderRadius: rBtn,
          borderSide: outlineSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: rBtn,
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        hintStyle: tt.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: rChip),
        side: outlineVariantSide,
        backgroundColor: cs.surfaceContainerLow,
        selectedColor: cs.primaryContainer,
        labelStyle: tt.labelLarge?.copyWith(color: cs.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: rBtn),
          ),
          backgroundColor: WidgetStatePropertyAll(cs.primary),
          foregroundColor: WidgetStatePropertyAll(cs.onPrimary),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(tt.labelLarge),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: rBtn),
          ),
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          foregroundColor: WidgetStatePropertyAll(cs.onSurface),
          side: WidgetStatePropertyAll(outlineSide),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: rBtn),
          ),
          side: WidgetStatePropertyAll(outlineSide),
          foregroundColor: WidgetStatePropertyAll(cs.onSurface),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(cs.primary)),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(cs.onSurfaceVariant),
        ),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: rSmall),
        selectedTileColor: cs.primaryContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),

      iconTheme: IconThemeData(size: 18, color: cs.onSurfaceVariant),

      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: rCard),
        titleTextStyle: tt.titleLarge,
        contentTextStyle: tt.bodyMedium,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainerHigh,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: rSmall,
          side: outlineVariantSide,
        ),
        textStyle: tt.bodyMedium,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHigh,
      ),

      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: rSmall),
        tilePadding: EdgeInsets.zero,
        iconColor: cs.onSurfaceVariant,
        collapsedIconColor: cs.onSurfaceVariant,
      ),

      tooltipTheme: TooltipThemeData(
        textStyle: tt.bodySmall,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(tok.radiusSmall),
        ),
      ),
    );
  }
}
