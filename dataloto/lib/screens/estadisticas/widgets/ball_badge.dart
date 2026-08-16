import 'package:flutter/material.dart';
import 'package:dataloto/styles/app_text_styles.dart';

class BallBadge extends StatelessWidget {
  final int num;
  final String sub;
  final Color color;

  const BallBadge({
    Key? key,
    required this.num,
    required this.sub,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                "$num",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
