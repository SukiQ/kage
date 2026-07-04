import 'dart:ui';

import 'package:flutter/material.dart';

/// Kage 设计 token：间距与圆角网格（中性，不随明暗/角色变化）。
/// 通过 ThemeData.extensions 注入，消费处用 [KageDesignTokens.of]。
/// 角色点缀色不再放此处——由 ColorScheme.primary（角色 accent）驱动，见 chat_view。
class KageDesignTokens extends ThemeExtension<KageDesignTokens> {
  const KageDesignTokens({
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.radius,
    required this.radiusButton,
    required this.radiusInput,
    required this.radiusChip,
    required this.radiusSmall,
    required this.borderWidth,
  });

  /// 间距网格：4 / 8 / 12 / 16
  final double space1, space2, space3, space4;

  /// 圆角：卡片/气泡/面板/对话框=16，按钮/输入框=14，chip=16，小元素=12
  final double radius, radiusButton, radiusInput, radiusChip, radiusSmall;
  final double borderWidth;

  static KageDesignTokens of(BuildContext context) =>
      Theme.of(context).extension<KageDesignTokens>()!;

  static const light = KageDesignTokens(
    space1: 4,
    space2: 8,
    space3: 12,
    space4: 16,
    radius: 16,
    radiusButton: 14,
    radiusInput: 14,
    radiusChip: 16,
    radiusSmall: 12,
    borderWidth: 1,
  );

  static const dark = KageDesignTokens(
    space1: 4,
    space2: 8,
    space3: 12,
    space4: 16,
    radius: 16,
    radiusButton: 14,
    radiusInput: 14,
    radiusChip: 16,
    radiusSmall: 12,
    borderWidth: 1,
  );

  @override
  KageDesignTokens copyWith({
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? radius,
    double? radiusButton,
    double? radiusInput,
    double? radiusChip,
    double? radiusSmall,
    double? borderWidth,
  }) => KageDesignTokens(
    space1: space1 ?? this.space1,
    space2: space2 ?? this.space2,
    space3: space3 ?? this.space3,
    space4: space4 ?? this.space4,
    radius: radius ?? this.radius,
    radiusButton: radiusButton ?? this.radiusButton,
    radiusInput: radiusInput ?? this.radiusInput,
    radiusChip: radiusChip ?? this.radiusChip,
    radiusSmall: radiusSmall ?? this.radiusSmall,
    borderWidth: borderWidth ?? this.borderWidth,
  );

  @override
  KageDesignTokens lerp(ThemeExtension<KageDesignTokens>? other, double t) {
    if (other is! KageDesignTokens) return this;
    return KageDesignTokens(
      space1: lerpDouble(space1, other.space1, t)!,
      space2: lerpDouble(space2, other.space2, t)!,
      space3: lerpDouble(space3, other.space3, t)!,
      space4: lerpDouble(space4, other.space4, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
      radiusButton: lerpDouble(radiusButton, other.radiusButton, t)!,
      radiusInput: lerpDouble(radiusInput, other.radiusInput, t)!,
      radiusChip: lerpDouble(radiusChip, other.radiusChip, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
    );
  }
}
