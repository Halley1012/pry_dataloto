import 'package:flutter/material.dart';
import 'package:eterlotto/styles/app_text_styles.dart';

class BallBadge extends StatelessWidget {
  final int num;
  final String sub;
  final Color color;
  final bool isHighlighted;
  final Color? highlightColor;

  const BallBadge({
    super.key,
    required this.num,
    required this.sub,
    required this.color,
    this.isHighlighted = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeHighlight = highlightColor ?? const Color(0xFF00E5FF);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHighlighted ? const Color(0xFF16222F) : color,
              border: isHighlighted
                  ? Border.all(color: activeHighlight, width: 2.0)
                  : null,
              boxShadow: [
                if (isHighlighted)
                  BoxShadow(
                    color: activeHighlight.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                else
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
              ],
            ),
            child: Center(
              child: Text(
                "$num",
                style: TextStyle(
                  color: isHighlighted ? activeHighlight : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(sub, style: AppTextStyles.caption2),
        ],
      ),
    );
  }
}
