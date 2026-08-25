import 'package:flutter/material.dart';
import 'package:eterlotto/widgets/cardbussiness.dart'; // Asume que BusinessCard está aquí
import 'dart:async';

class InfiniteAdsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> anuncios;
  final VoidCallback? onAction;

  const InfiniteAdsCarousel({super.key, required this.anuncios, this.onAction});

  @override
  State<InfiniteAdsCarousel> createState() => _InfiniteAdsCarouselState();
}

class _InfiniteAdsCarouselState extends State<InfiniteAdsCarousel> {
  late PageController _pageController;
  bool _isAnimating = false;
  Timer? _carouselTimer;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0, initialPage: 0);
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (widget.anuncios.isNotEmpty && widget.anuncios.length > 1) {
      _carouselTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
        if (_pageController.hasClients &&
            widget.anuncios.isNotEmpty &&
            !_isAnimating) {
          _isAnimating = true;
          _pageController
              .nextPage(
                duration: const Duration(milliseconds: 4000),
                curve: Curves.easeInOut,
              )
              .then((_) {
                if (mounted) {
                  _isAnimating = false;
                }
              });
        }
      });
    }
  }

  String _getLocation(Map<String, dynamic> anuncio) {
  final city = anuncio["ciudad_nombre"] as String?;
  if (city?.isNotEmpty == true) return city!;
  return anuncio["departamento_nombre"] as String? ?? "";
}


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.3, // Altura dinámica
      child: PageView.builder(
        controller: _pageController,
        physics: const PageScrollPhysics(),
        itemCount: widget.anuncios.isNotEmpty ? 10000 : 0, // Ciclo infinito
        onPageChanged: (index) {
          setState(() {
            currentIndex = index % widget.anuncios.length;
          });
        },
        itemBuilder: (context, index) {
          if (widget.anuncios.isEmpty) return const SizedBox();
          final anuncio = widget.anuncios[index % widget.anuncios.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.3),
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20.0),
                    child: BusinessCard(
                      paginaweb: anuncio["pagina_url"] ?? "",
                      title: anuncio["titulo"] ?? "",
                      logo: anuncio["imagen_url"] ?? "",
                      description: anuncio["descripcion"] ?? "",
                      address: anuncio["direccion"] ?? "",
                      city: _getLocation(anuncio),
                      contact: anuncio["telefono"] ?? "",
                      whatsappUrl: anuncio["whatsapp_url"],
                      facebookUrl: anuncio["facebook_url"],
                      instagramUrl: anuncio["instagram_url"],
                      onAction: widget.onAction ?? () {},
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
