// 📁 lib/widgets/footer.dart
import 'package:flutter/material.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Footer extends StatefulWidget {
  const Footer({super.key});

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  String _version = '1';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version; // Solo mostrará "1.1.0"
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(
          top: BorderSide(
            color: Colors.white24, // 🔹 borde sutil para separar el footer
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 1),
          Text(
            _version.isNotEmpty
                ? "© 2025 DataLoto. Todos los derechos reservados. | Versión $_version"
                : "© 2025 DataLoto. Todos los derechos reservados.",
            style: AppTextStyles.caption.copyWith(
              color: Colors.white54,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
