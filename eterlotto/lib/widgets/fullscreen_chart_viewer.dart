import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/colores.dart';
import '../styles/app_text_styles.dart';

class FullScreenChartViewer extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget chartWidget;

  const FullScreenChartViewer({
    super.key,
    required this.title,
    this.subtitle,
    required this.chartWidget,
  });

  static void show(BuildContext context, {required String title, String? subtitle, required Widget chartWidget}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenChartViewer(
          title: title,
          subtitle: subtitle,
          chartWidget: chartWidget,
        ),
      ),
    );
  }

  @override
  State<FullScreenChartViewer> createState() => _FullScreenChartViewerState();
}

class _FullScreenChartViewerState extends State<FullScreenChartViewer> {
  bool _isLandscape = false;

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: AppColors.blackfondo,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: AppTextStyles.h2.copyWith(fontSize: 16, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: AppTextStyles.caption.copyWith(fontSize: 11, color: Colors.white54),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation,
              color: AppColors.yellow,
              size: 22,
            ),
            tooltip: _isLandscape ? "Modo Vertical" : "Girar Pantalla (Horizontal)",
            onPressed: _toggleOrientation,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3), width: 1),
            ),
            child: widget.chartWidget,
          ),
        ),
      ),
    );
  }
}
