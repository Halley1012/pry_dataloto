import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class PublicidadDetailScreen extends StatefulWidget {
  final Map<String, dynamic> publicidad;

  const PublicidadDetailScreen({
    super.key,
    required this.publicidad,
  });

  @override
  State<PublicidadDetailScreen> createState() => _PublicidadDetailScreenState();
}

class _PublicidadDetailScreenState extends State<PublicidadDetailScreen> {
  late Map<String, dynamic> _ad;
  late final PageController _pageController;
  int _page = 0;
  bool _savingLike = false;
  bool _savingRating = false;

  @override
  void initState() {
    super.initState();
    _ad = Map<String, dynamic>.from(widget.publicidad);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'si';
  }

  List<String> _images() {
    final result = <String>[];
    void add(dynamic raw) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty && !result.contains(value)) result.add(value);
    }

    add(_ad['imagen_url']);
    final gallery = _ad['galeria_urls'];
    if (gallery is List) {
      for (final item in gallery) {
        add(item);
      }
    } else if (gallery is String && gallery.trim().isNotEmpty) {
      for (final item in gallery.split(RegExp(r'[\n,;]+'))) {
        add(item);
      }
    }
    return result;
  }

  String _formatLikes(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) {
      final k = count / 1000.0;
      return k < 10 ? '${k.toStringAsFixed(1)}K' : '${k.toStringAsFixed(0)}K';
    }
    final m = count / 1000000.0;
    return m < 10 ? '${m.toStringAsFixed(1)}M' : '${m.toStringAsFixed(0)}M';
  }

  String _scheduleStatus() {
    if (_asBool(_ad['es_24_7'])) {
      return AppLocalizations.of(context)!.abierto247;
    }
    final open = _ad['hora_apertura']?.toString();
    final close = _ad['hora_cierre']?.toString();
    if (open != null && close != null && open.contains(':') && close.contains(':')) {
      try {
        final now = DateTime.now();
        final a = open.split(':');
        final c = close.split(':');
        final current = now.hour * 60 + now.minute;
        final start = int.parse(a[0]) * 60 + int.parse(a[1]);
        final end = int.parse(c[0]) * 60 + int.parse(c[1]);
        final isOpen = start <= end
            ? current >= start && current <= end
            : current >= start || current <= end;
        return isOpen
            ? AppLocalizations.of(context)!.abiertoAhora
            : AppLocalizations.of(context)!.cerradoAhora;
      } catch (_) {}
    }
    return _ad['estado_texto']?.toString() ?? '';
  }

  String _scheduleDetail() {
    if (_asBool(_ad['es_24_7'])) {
      return AppLocalizations.of(context)!.abiertoTodoDia;
    }
    final days = _ad['dias_atencion']?.toString().trim() ?? '';
    final open = _ad['hora_apertura']?.toString().trim() ?? '';
    final close = _ad['hora_cierre']?.toString().trim() ?? '';
    final parts = <String>[];
    if (days.isNotEmpty) parts.add(days);
    if (open.isNotEmpty && close.isNotEmpty) parts.add('$open - $close');
    return parts.join(' · ');
  }

  Future<void> _launch(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    var value = url.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _call() async {
    final raw = _ad['telefono']?.toString() ?? '';
    final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _maps() async {
    final address = _ad['direccion']?.toString().trim() ?? '';
    final city = _ad['ciudad_nombre']?.toString().trim() ?? '';
    final dept = _ad['departamento_nombre']?.toString().trim() ?? '';
    final query = [address, city, dept].where((e) => e.isNotEmpty).join(', ');
    if (query.isEmpty) return;
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_savingLike) return;
    final id = _toInt(_ad['id']);
    if (id <= 0) return;

    final oldFav = _ad['is_favorite'] == true;
    final oldLikes = _toInt(_ad['total_likes']);
    setState(() {
      _savingLike = true;
      _ad['is_favorite'] = !oldFav;
      _ad['total_likes'] = !oldFav ? oldLikes + 1 : (oldLikes > 0 ? oldLikes - 1 : 0);
    });

    try {
      final res = await ApiService.toggleFavoritoPublicidad(id);
      if (!mounted) return;
      setState(() {
        if (res['is_favorite'] != null) _ad['is_favorite'] = res['is_favorite'] == true;
        if (res['total_likes'] != null) _ad['total_likes'] = _toInt(res['total_likes']);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ad['is_favorite'] = oldFav;
        _ad['total_likes'] = oldLikes;
      });
      _snack(AppLocalizations.of(context)!.errorActualizarMeGusta);
    } finally {
      if (mounted) setState(() => _savingLike = false);
    }
  }

  Future<void> _rate(int stars) async {
    if (_savingRating) return;
    final id = _toInt(_ad['id']);
    if (id <= 0) return;
    setState(() => _savingRating = true);
    try {
      final res = await ApiService.calificarPublicidad(id, stars);
      if (!mounted) return;
      setState(() {
        _ad['user_rating'] = res['user_rating'] ?? stars;
        _ad['promedio_estrellas'] = res['promedio'] ?? _ad['promedio_estrellas'];
        _ad['total_calificaciones'] = res['total_votos'] ?? _ad['total_calificaciones'];
        if (res['is_destacado'] != null) _ad['is_destacado'] = res['is_destacado'];
      });
      _snack(AppLocalizations.of(context)!.calificacionGuardada);
    } catch (_) {
      _snack(AppLocalizations.of(context)!.errorGuardarCalificacion);
    } finally {
      if (mounted) setState(() => _savingRating = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white)),
        backgroundColor: const Color(0xFF263238),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openImageViewer(List<String> images, int initialIndex) {
    if (images.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PublicidadImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openGallery(List<String> images) {
    if (images.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.galeriaLabel,
                style: AppTextStyles.tituloPrincipal.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: images.length,
                  itemBuilder: (_, index) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Future.microtask(() => _openImageViewer(images, index));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white10,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _images();
    final title = _ad['titulo']?.toString() ?? '';
    final shortDescription = _ad['descripcion']?.toString() ?? '';
    final about = (_ad['about_us']?.toString().trim().isNotEmpty == true)
        ? _ad['about_us'].toString().trim()
        : shortDescription;
    final category = _ad['categoria_nombre']?.toString() ?? '';
    final address = _ad['direccion']?.toString() ?? '';
    final city = _ad['ciudad_nombre']?.toString() ?? '';
    final dept = _ad['departamento_nombre']?.toString() ?? '';
    final phone = _ad['telefono']?.toString() ?? '';
    final average = _toDouble(_ad['promedio_estrellas']);
    final votes = _toInt(_ad['total_calificaciones']);
    final likes = _toInt(_ad['total_likes']);
    final userRating = _toInt(_ad['user_rating']);
    final favorite = _ad['is_favorite'] == true;
    final status = _scheduleStatus();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _ad);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090C0F),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  SizedBox(
                    height: 255,
                    width: double.infinity,
                    child: images.isEmpty
                        ? Container(
                            color: const Color(0xFF171C21),
                            child: const Icon(Icons.storefront, color: Colors.white24, size: 72),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            onPageChanged: (value) => setState(() => _page = value),
                            itemBuilder: (_, index) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openImageViewer(images, index),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: 18,
                                      sigmaY: 18,
                                    ),
                                    child: Image.network(
                                      images[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF171C21),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.22),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    child: Image.network(
                                      images[index],
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF171C21),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white24,
                                          size: 64,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.72)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _roundIconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context, _ad)),
                          GestureDetector(
                            onTap: _savingLike ? null : _toggleLike,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.42),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : AppColors.yellow),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatLikes(likes),
                                    style: AppTextStyles.caption2.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 18,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          final selected = index == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: selected ? 9 : 6,
                            height: selected ? 9 : 6,
                            decoration: BoxDecoration(
                              color: selected ? AppColors.yellow : Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D1216),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _launch(
                              _ad['pagina_url']?.toString(),
                            ),
                            behavior: HitTestBehavior.opaque,
                            child: ClipOval(
                              child: images.isNotEmpty
                                  ? Image.network(
                                      images.first,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.white10,
                                      child: const Icon(
                                        Icons.store,
                                        color: Colors.white38,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _launch(
                                    _ad['pagina_url']?.toString(),
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  child: Text(
                                    title,
                                    style: AppTextStyles.tituloPrincipal.copyWith(
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (category.isNotEmpty)
                                      _chip(Icons.category_outlined, category, AppColors.yellow),
                                    if (status.isNotEmpty)
                                      _chip(Icons.circle, status, const Color(0xFF00E676), iconSize: 8),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 1,
                                children: [
                                  ...List.generate(5, (index) {
                                    final active = index < average.round();
                                    return Icon(active ? Icons.star : Icons.star_border, color: AppColors.yellow, size: 19);
                                  }),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${average.toStringAsFixed(1)} ($votes)',
                                    style: AppTextStyles.caption.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 26, color: Colors.white12),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _savingLike ? null : _toggleLike,
                              child: Row(
                                children: [
                                  Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : Colors.white70, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatLikes(likes),
                                    style: AppTextStyles.caption2.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        shortDescription,
                        style: AppTextStyles.mensajeSecundario.copyWith(
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (address.isNotEmpty) _infoRow(Icons.location_on_outlined, address, onTap: _maps),
                      if (city.isNotEmpty || dept.isNotEmpty)
                        _infoRow(Icons.apartment_outlined, [city, dept].where((e) => e.isNotEmpty).join(', ')),
                      if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, phone, onTap: _call),
                      const SizedBox(height: 18),
                      _socialButtons(),
                      const SizedBox(height: 24),
                      _sectionTitle(Icons.pets, AppLocalizations.of(context)!.sobreNosotros),
                      const SizedBox(height: 8),
                      Text(
                        about,
                        style: AppTextStyles.mensajeSecundario.copyWith(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle(Icons.schedule, AppLocalizations.of(context)!.horarioAtencion),
                      const SizedBox(height: 8),
                      Text(
                        _scheduleDetail(),
                        style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle(Icons.star_rate_rounded, AppLocalizations.of(context)!.tuCalificacion),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          final value = index + 1;
                          final selected = value <= userRating;
                          return IconButton(
                            tooltip: '$value',
                            onPressed: _savingRating ? null : () => _rate(value),
                            icon: Icon(selected ? Icons.star : Icons.star_border, color: AppColors.yellow, size: 30),
                          );
                        }),
                      ),
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _sectionTitle(Icons.photo_library_outlined, AppLocalizations.of(context)!.galeriaLabel),
                            TextButton(
                              onPressed: () => _openGallery(images),
                              child: Text(
                                AppLocalizations.of(context)!.verTodas,
                                style: AppTextStyles.caption2.copyWith(
                                  color: AppColors.yellow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, index) => GestureDetector(
                              onTap: () => _openImageViewer(images, index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  images[index],
                                  width: 92,
                                  height: 92,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 92, height: 92, color: Colors.white10, child: const Icon(Icons.broken_image_outlined, color: Colors.white38)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: IconButton(onPressed: onTap, icon: Icon(icon, color: AppColors.yellow)),
    );
  }

  Widget _chip(IconData icon, String text, Color color, {double iconSize = 16}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.caption2.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.yellow, size: 22),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.mensajeImportante.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: onTap != null ? AppColors.yellow : Colors.white54, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? child : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child);
  }

  Widget _socialButtons() {
    final items = <Widget>[];
    void add(FaIconData icon, String label, Color color, String? url) {
      if (url == null || url.trim().isEmpty) return;
      items.add(
        Expanded(
          child: GestureDetector(
            onTap: () => _launch(url),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(icon, color: color, size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    add(FontAwesomeIcons.facebookF, 'Facebook', const Color(0xFF1877F2), _ad['facebook_url']?.toString());
    add(FontAwesomeIcons.instagram, 'Instagram', const Color(0xFFE4405F), _ad['instagram_url']?.toString());
    add(FontAwesomeIcons.whatsapp, 'WhatsApp', const Color(0xFF25D366), _ad['whatsapp_url']?.toString());

    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          items[i],
        ],
      ],
    );
  }
}

class _PublicidadImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _PublicidadImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_PublicidadImageViewer> createState() => _PublicidadImageViewerState();
}

class _PublicidadImageViewerState extends State<_PublicidadImageViewer> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (_, index) {
              return SafeArea(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${_current + 1} / ${widget.images.length}',
                      style: AppTextStyles.caption2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

