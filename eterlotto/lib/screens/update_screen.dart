import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class UpdateScreen extends StatelessWidget {
  final String androidUrl;
  final String iosUrl;

  const UpdateScreen({
    super.key,
    required this.androidUrl,
    required this.iosUrl,
  });

  Future<void> _openStore() async {
    final urlString = Platform.isAndroid ? androidUrl : iosUrl;
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Tu color oscuro habitual
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.system_update_rounded, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 32),
            const Text(
              'Actualización Requerida',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Hemos lanzado una nueva versión con mejoras importantes y correcciones. Por favor, actualiza Eterlotto para continuar.',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openStore,
                child: const Text(
                  'Actualizar Ahora', 
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
