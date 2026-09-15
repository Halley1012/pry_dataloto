import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/services/ad_service.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'resultados_shared.dart';

class InsightIaCard extends StatelessWidget {
  final String insightIAText;
  final String selectedLoteria;
  final int probablesCount;
  final double coberturaPorcentaje;
  final List<SubSorteoData> subSorteos;
  final String fechaSorteo;
  final List<int>? predictionNumeros;
  final List<int>? predictionBalotaroja;

  const InsightIaCard({
    super.key,
    required this.insightIAText,
    required this.selectedLoteria,
    required this.probablesCount,
    required this.coberturaPorcentaje,
    required this.subSorteos,
    required this.fechaSorteo,
    this.predictionNumeros,
    this.predictionBalotaroja,
  });

  int _getTopLimit() {
    final available = predictionNumeros?.length ?? 0;
    if (available <= 0) return 0;

    if (probablesCount > 0) {
      return probablesCount < available ? probablesCount : available;
    }

    // Si el padre no indicó un límite, usamos exactamente la lista recibida.
    // El widget ya no conoce nombres ni reglas particulares de loterías.
    return available;
  }

  Widget _build3DBall(int? numero, {Color baseColor = const Color(0xFFF33A21), double size = 45}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.8),
            baseColor.withValues(alpha: 0.6),
          ],
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(1.5, 1.5),
            blurRadius: 3,
          ),
        ],
        border: Border.all(color: Colors.white24, width: 1.0),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? "",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: numero != null
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  void _showProbablesDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.tendenciasIA,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return _buildDialogContent(ctx, l10n);
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildDialogContent(BuildContext context, AppLocalizations l10n) {
    final limit = _getTopLimit();
    final hasSpecial = predictionBalotaroja != null && predictionBalotaroja!.isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    const crossAxisCount = 10;
    final double spacing = screenWidth < 360 ? 4.0 : 6.0;
    final availableWidth = screenWidth - 32.0 - 40.0;
    final double ballSize = ((availableWidth - (spacing * 9)) / 10).floorToDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF2C2F38)],
            transform: GradientRotation(12),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${l10n.tendenciasIA} - $selectedLoteria",
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.sorteoDel(fechaSorteo),
                    style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white38),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.aciertoIA,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (subSorteos.length > 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: subSorteos.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final sub = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: idx < subSorteos.length - 1 ? 8.0 : 0.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 85,
                            child: Text(
                              "${sub.nombre}: ",
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sub.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...sub.winningNums.map((n) {
                                    final isHit = predictionNumeros?.contains(n) ?? false;
                                    final baseColor = isHit ? sub.color : const Color(0xFF334155);
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 5.0),
                                      child: _build3DBall(
                                        n,
                                        baseColor: baseColor,
                                        size: 25,
                                      ),
                                    );
                                  }),
                                  ...sub.winningSpecials.map(
                                    (special) => Padding(
                                      padding: const EdgeInsets.only(left: 3),
                                      child: _build3DBall(
                                        special,
                                        baseColor: Colors.redAccent,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else if (subSorteos.isNotEmpty)
                Row(
                  children: [
                    Text(
                      "${l10n.resultadoReal}: ",
                      style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...subSorteos.first.winningNums.map((n) {
                              final isHit = predictionNumeros?.contains(n) ?? false;
                              final baseColor = isHit ? Colors.amber : const Color(0xFF607D8B);
                              return Padding(
                                padding: const EdgeInsets.only(right: 5.0),
                                child: _build3DBall(
                                  n,
                                  baseColor: baseColor,
                                  size: 25,
                                ),
                              );
                            }),
                            ...subSorteos.first.winningSpecials.map(
                              (special) => Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: _build3DBall(
                                  special,
                                  baseColor: Colors.redAccent,
                                  size: 25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.balotasPrincipalesTitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.numerosOrdenadosProbabilidad,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                      predictionNumeros == null || predictionNumeros!.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Text(
                                l10n.noHayTendencias,
                                style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white54),
                              ),
                            )
                          : GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              children: predictionNumeros!.asMap().entries.map((entry) {
                                int index = entry.key;
                                int n = entry.value;

                                Color baseColor = index < limit ? Colors.redAccent : const Color(0xFF607D8B);
                                for (var sub in subSorteos) {
                                  if (sub.winningNums.contains(n)) {
                                    baseColor = sub.color;
                                    break;
                                  }
                                }

                                return _build3DBall(
                                  n,
                                  baseColor: baseColor,
                                  size: ballSize,
                                );
                              }).toList(),
                            ),
                      if (hasSpecial) ...[
                        const SizedBox(height: 10),
                        Text(
                          l10n.balotasRojasEspeciales,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.numerosOrdenadosProbabilidad,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          children: predictionBalotaroja!.map((n) {
                            Color baseColor = Colors.redAccent;
                            for (var sub in subSorteos) {
                              if (sub.winningSpecials.contains(n)) {
                                baseColor = sub.color;
                                break;
                              }
                            }

                            return _build3DBall(
                              n,
                              baseColor: baseColor,
                              size: ballSize,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
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
    final l10n = AppLocalizations.of(context)!;
    final bool hasPrediction =
        predictionNumeros != null && predictionNumeros!.isNotEmpty;
    final text = !hasPrediction
        ? l10n.prediccionesNoDisponibles
        : (insightIAText.isNotEmpty
              ? insightIAText
              : (subSorteos.isNotEmpty
                    ? l10n.insightIACayeron(
                        probablesCount,
                        selectedLoteria,
                        l10n.nNumeros(
                          (coberturaPorcentaje *
                                  subSorteos.first.winningNums.length)
                              .round(),
                        ),
                      )
                    : ""));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF064E3B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart, color: Colors.greenAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("💡", style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      l10n.insightsIA,
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fechaSorteo, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38)),
                    GestureDetector(
                      onTap: hasPrediction
                          ? () {
                              final isPremium = context
                                  .read<SubscriptionProvider>()
                                  .isSubscribed;
                              AdService.instance.showRewardedFeatureGate(
                                context: context,
                                isPremium: isPremium,
                                featureKey: "tendencias_ia",
                                featureTitle: l10n.tendenciasIA,
                                featureActionDescription:
                                    l10n.descripcionVideoInsight,
                                onRewardGranted: () =>
                                    _showProbablesDialog(context),
                              );
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (hasPrediction ? Colors.amber : Colors.white38)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: hasPrediction ? Colors.amber : Colors.white38,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
