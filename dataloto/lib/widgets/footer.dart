// 📁 lib/widgets/footer.dart
import 'package:flutter/material.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';

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
      _version = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final derechos = l10n?.derechosReservados ?? "© 2025 DataLoto. Todos los derechos reservados.";
    final lblVersion = l10n?.version ?? "Versión";
    final text = _version.isNotEmpty ? "$derechos | $lblVersion $_version" : derechos;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(
          top: BorderSide(
            color: Colors.white12,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            text,
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
