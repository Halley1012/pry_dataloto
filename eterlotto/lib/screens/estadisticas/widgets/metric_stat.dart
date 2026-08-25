import 'package:flutter/material.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/styles/colores.dart';

class MetricStat extends StatelessWidget {
  final String label;
  final String value;

  const MetricStat({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.tituloPrincipal.copyWith(
            color: AppColors.yellow,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
