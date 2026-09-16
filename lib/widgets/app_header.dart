import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final EdgeInsets padding;
  final bool dark;

  const AppHeader({
    super.key,
    this.iconSize = 48,
    this.fontSize = 24,
    this.padding = const EdgeInsets.all(0),
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1A3A6B),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(iconSize / 2),
              child: Image.asset('assets/icon/wy_icon.png'),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'WhoYou',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: dark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
