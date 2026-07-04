import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 标题栏品牌标识：logo + 「Kage」文字，集中复用。
class KageBrand extends StatelessWidget {
  const KageBrand({super.key, this.iconSize = 18, this.fontSize = 14});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/images/logo.svg',
          width: iconSize,
          height: iconSize,
        ),
        const SizedBox(width: 6),
        Text(
          'Kage',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
