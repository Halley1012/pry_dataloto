import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/providers/combination_generator_provider.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/utils/secure_storage_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class _CombinationGeneratorSkeleton extends StatefulWidget {
  const _CombinationGeneratorSkeleton();

  @override
  State<_CombinationGeneratorSkeleton> createState() =>
      _CombinationGeneratorSkeletonState();
}

class _CombinationGeneratorSkeletonState
    extends State<_CombinationGeneratorSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box({
    double height = 16,
    double? width,
    double radius = 8,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final opacity = 0.12 + (_controller.value * 0.10);
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(height: 52, width: 52, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(height: 17, width: 230),
                    const SizedBox(height: 8),
                    _box(height: 12, width: double.infinity),
                    const SizedBox(height: 5),
                    _box(height: 12, width: 190),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 14, width: 150),
                const SizedBox(height: 12),
                _box(height: 50, width: double.infinity, radius: 10),
              ],
            ),
          ),
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 14, width: 125),
                const SizedBox(height: 12),
                _box(height: 54, width: double.infinity, radius: 10),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _box(height: 28, width: 70, radius: 14),
                    const SizedBox(width: 8),
                    _box(height: 28, width: 70, radius: 14),
                    const SizedBox(width: 8),
                    _box(height: 28, width: 70, radius: 14),
                  ],
                ),
              ],
            ),
          ),
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 14, width: 145),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _box(height: 48, radius: 10)),
                    const SizedBox(width: 10),
                    _box(height: 48, width: 70, radius: 10),
                  ],
                ),
              ],
            ),
          ),
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 14, width: 120),
                const SizedBox(height: 12),
                _box(height: 48, width: double.infinity, radius: 10),
                const SizedBox(height: 12),
                _box(height: 40, width: double.infinity, radius: 10),
              ],
            ),
          ),
          _box(height: 52, width: double.infinity, radius: 14),
          const SizedBox(height: 24),
          _box(height: 18, width: 170),
          const SizedBox(height: 12),
          _box(height: 100, width: double.infinity, radius: 14),
        ],
      ),
    );
  }
}

class CombinationGeneratorScreen extends StatefulWidget {
  const CombinationGeneratorScreen({super.key});

  @override
  State<CombinationGeneratorScreen> createState() => _CombinationGeneratorScreenState();
}

class _CombinationGeneratorScreenState extends State<CombinationGeneratorScreen> {
  final TextEditingController _inputController = TextEditingController();
  late CombinationGeneratorProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = CombinationGeneratorProvider();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _provider.reload();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: AppColors.blackfondo,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Eterlotto',
            style: GoogleFonts.montserrat(
              color: AppColors.yellow,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Consumer<SubscriptionProvider>(
              builder: (_, sub, __) => sub.isPremium
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: PremiumCrownIcon(isPremium: true, size: 19),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white70),
              onPressed: () {},
            )
          ],
        ),
        body: Consumer<CombinationGeneratorProvider>(
          builder: (context, provider, child) {
            final l10n = AppLocalizations.of(context);

            // Si aún no hay datos, mostramos Skeleton en lugar de bloquear
            // toda la pantalla con un spinner.
            if (provider.isLoadingLotteries && provider.supportedLotteries.isEmpty) {
              return const _CombinationGeneratorSkeleton();
            }

            return RefreshIndicator(
              color: AppColors.yellow,
              backgroundColor: AppColors.darkGray,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title section ──────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.yellow.withValues(alpha: 0.2),
                          ),
                          child: const Icon(Icons.casino, color: AppColors.yellow, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.generaTusPropiasCombinaciones ?? "Genera tus propias combinaciones",
                                style: AppTextStyles.h2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n?.usaTusNumerosFavoritos ?? "Usa tus números favoritos y crea jugadas personalizadas.",
                                style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Lottery Selection ──────────────────────────────────
                    _buildSectionContainer(
                      title: l10n?.seleccionaLaLoteria ?? "Selecciona la lotería",
                      icon: Icons.emoji_events,
                      child: Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E24),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: provider.selectedLottery,
                                        dropdownColor: AppColors.blackfondo,
                                        isExpanded: true,
                                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                                        style: GoogleFonts.montserrat(color: Colors.white),
                                        items: provider.supportedLotteries.map((rule) {
                                          return DropdownMenuItem(
                                            value: rule.lotteryId,
                                            child: Row(
                                              children: [
                                                Text(_countryFlag(rule.country), style: const TextStyle(fontSize: 16)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        rule.name,
                                                        style: GoogleFonts.montserrat(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (rule.country.isNotEmpty)
                                                        Text(
                                                          rule.country,
                                                          style: GoogleFonts.montserrat(
                                                            color: Colors.white54,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w400,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) provider.setLottery(val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E24),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_month_outlined, color: Colors.white70, size: 20),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                l10n?.proximoSorteo ?? "Próximo sorteo",
                                                style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                provider.selectedLotteryRules?.proximoSorteo != null
                                                    ? _formatFullDate(provider.selectedLotteryRules!.proximoSorteo!)
                                                    : "Por definir",
                                                style: GoogleFonts.montserrat(
                                                  color: AppColors.yellow,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Rules badge below the dropdown
                          if (provider.selectedLotteryRules != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.yellow.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: AppColors.yellow, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      provider.selectedLotteryRules!.rulesDescription,
                                      style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              l10n?.cargandoReglas ?? "Cargando reglas...",
                              style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Input Numbers ──────────────────────────────────────
                    _buildSectionContainer(
                      title: l10n?.tusNumeros ?? "Tus números",
                      subtitle: l10n?.ingresaNumerosFecha ?? "Ingresa números, una fecha o valores que tengan significado para ti.",
                      icon: Icons.person,
                      action: InkWell(
                        onTap: () {
                          _inputController.clear();
                          provider.setInputData("");
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "Limpiar",
                                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _inputController,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9\s/\-.,]')),
                        ],
                        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        onChanged: provider.setInputData,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E1E24),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                          ),
                          hintText: l10n?.ejemploNumeros ?? "Ej: 10 12 86, 12/10/1986...",
                          hintStyle: GoogleFonts.montserrat(color: Colors.white30, fontSize: 13),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () {
                              _inputController.clear();
                              provider.setInputData("");
                            },
                          ),
                        ),
                      ),
                    ),

                    // ── Card: Números detectados (Own separate card) ────────
                    if (provider.detectedNumbers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildSectionContainer(
                        title: l10n?.numerosDetectados ?? "Números detectados",
                        icon: Icons.auto_awesome,
                        subtitle: "Toca cualquier número que no quieras utilizar para excluirlo.",
                        action: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "${provider.activeNumbers.length} de ${provider.detectedNumbers.length} activos",
                            style: GoogleFonts.montserrat(
                              color: const Color(0xFF81C784),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: provider.detectedNumbers.map((n) {
                            return _buildInteractiveBalota(
                              number: n,
                              isExcluded: provider.isNumberExcluded(n),
                              onTap: () => provider.toggleExcludeNumber(n),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // ── Quantity + Strategy (EXACT SAME HEIGHT & DIMENSIONS) ─
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: Cantidad de jugadas
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.tag, color: AppColors.yellow, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          l10n?.cantidadDeJugadas ?? "Cantidad de jugadas",
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildCounterBtn(
                                        Icons.remove,
                                        provider.decrementQuantity,
                                        enabled: provider.quantity > 1,
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        constraints: const BoxConstraints(minWidth: 44),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E24),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "${provider.quantity}",
                                          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildCounterBtn(
                                        Icons.add,
                                        provider.incrementQuantity,
                                        enabled: provider.quantity < 10,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 28,
                                    child: Center(
                                      child: Text(
                                        "Se generarán hasta ${provider.quantity}\ncombinaciones únicas.",
                                        style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 9.5, height: 1.15),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Right: Estrategia
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.tune, color: AppColors.yellow, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          l10n?.estrategia ?? "Estrategia",
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E24),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.yellow, width: 1.2),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: provider.strategy,
                                        isExpanded: true,
                                        dropdownColor: AppColors.blackfondo,
                                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
                                        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11),
                                        items: [
                                          DropdownMenuItem(
                                            value: 'only_mine',
                                            child: Row(
                                              children: [
                                                const Text('🎯', style: TextStyle(fontSize: 12)),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text('Solo mis números', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'variations',
                                            child: Row(
                                              children: [
                                                const Text('✨', style: TextStyle(fontSize: 12)),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text('Variaciones', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'balanced',
                                            child: Row(
                                              children: [
                                                const Text('⚖️', style: TextStyle(fontSize: 12)),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text('Equilibradas', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) provider.setStrategy(val);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 28,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _getStrategyDescription(provider.strategy),
                                        style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 9.5, height: 1.15),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Generate button ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: provider.isLoading ? null : () => provider.generate(),
                        icon: provider.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, color: Colors.black),
                        label: Text(
                          provider.isLoading
                              ? (l10n?.generando ?? "GENERANDO...")
                              : (l10n?.generarCombinaciones ?? "GENERAR COMBINACIONES"),
                          style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.yellow,
                          disabledBackgroundColor: AppColors.yellow.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

                    if (provider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  provider.error!,
                                  style: GoogleFonts.montserrat(color: Colors.red, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Results ────────────────────────────────────────────
                    if (provider.combinations.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.grid_view_rounded, color: AppColors.yellow, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "${provider.combinations.length} ${l10n?.combinacionesGeneradas ?? 'combinaciones generadas'}",
                                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => provider.generate(),
                            icon: const Icon(Icons.refresh, color: Colors.white60, size: 16),
                            label: Text(
                              l10n?.generarOtras ?? "Generar otras",
                              style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Combinations list — vertical with copy and favorite actions
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.combinations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final combo = provider.combinations[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E24),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    "#${combo.number}",
                                    style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      ...combo.mainNumbers.map((n) => _buildMiniBalota(n, false)),
                                      ...combo.specialNumbers.map(
                                        (n) => _buildMiniBalota(n, true),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  tooltip: "Copiar",
                                  onPressed: () {
                                    final text = "${combo.mainNumbers.join(' · ')}${combo.specialNumbers.isNotEmpty ? ' + ${combo.specialNumbers.join(' · ')}' : ''}";
                                    Clipboard.setData(ClipboardData(text: text));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Combinación copiada al portapapeles",
                                          style: GoogleFonts.montserrat(fontSize: 12),
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.favorite_border_rounded, color: Colors.white38, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  tooltip: "Favorito",
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Marcada como favorita",
                                          style: GoogleFonts.montserrat(fontSize: 12),
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final l10nInner = AppLocalizations.of(context);
                            final storage = AppSecureStorage.instance;
                            final userId = await storage.read(key: "user_id");
                            if (!context.mounted) return;
                            if (userId != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10nInner?.guardando ?? 'Guardando...', style: GoogleFonts.montserrat(fontSize: 12))),
                              );
                              final success = await provider.saveAll(userId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? (l10nInner?.jugadasGuardadasConExito ?? 'Jugadas guardadas con éxito')
                                        : (l10nInner?.errorAlGuardarJugadas ?? 'Hubo un error al guardar algunas jugadas'),
                                    style: GoogleFonts.montserrat(fontSize: 12),
                                  ),
                                  backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              );
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10nInner?.debesIniciarSesionParaGuardar ?? 'Debes iniciar sesión para guardar',
                                    style: GoogleFonts.montserrat(fontSize: 12),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.file_download_outlined, color: AppColors.yellow, size: 20),
                          label: Text(
                            l10n?.guardarTodas ?? "Guardar todas",
                            style: GoogleFonts.montserrat(color: AppColors.yellow, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: AppColors.yellow, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback onPressed, {bool enabled = true}) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? const Color(0xFF1E1E24) : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: enabled ? AppColors.yellow : Colors.white12,
            width: 1.2,
          ),
        ),
        child: Icon(icon, color: enabled ? AppColors.yellow : Colors.white24, size: 18),
      ),
    );
  }

  Widget _buildInteractiveBalota({
    required int number,
    required bool isExcluded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isExcluded ? Colors.white.withValues(alpha: 0.05) : AppColors.yellow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExcluded ? Colors.white24 : AppColors.yellow,
            width: 1.2,
          ),
          boxShadow: isExcluded
              ? null
              : [
                  BoxShadow(
                    color: AppColors.yellow.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              number.toString(),
              style: GoogleFonts.montserrat(
                color: isExcluded ? Colors.white38 : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                decoration: isExcluded ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isExcluded ? Icons.add_circle_outline : Icons.cancel,
              size: 14,
              color: isExcluded ? Colors.white38 : Colors.black87,
            ),
          ],
        ),
      ),
    );
  }

  String _countryFlag(String country) {
    final c = country.toLowerCase().trim();
    if (c.contains('colombia')) return '🇨🇴';
    if (c.contains('españa') || c.contains('spain')) return '🇪🇸';
    if (c.contains('méxico') || c.contains('mexico')) return '🇲🇽';
    if (c.contains('estados unidos') || c.contains('usa') || c.contains('united states')) return '🇺🇸';
    if (c.contains('perú') || c.contains('peru')) return '🇵🇪';
    if (c.contains('brasil') || c.contains('brazil')) return '🇧🇷';
    if (c.contains('costa rica')) return '🇨🇷';
    if (c.contains('uruguay')) return '🇺🇾';
    if (c.contains('chile')) return '🇨🇱';
    if (c.contains('argentina')) return '🇦🇷';
    return '🌎';
  }

  Widget _buildSectionContainer({
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.yellow, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (action != null) action,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMiniBalota(int number, bool isSpecial) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSpecial ? Colors.red : AppColors.yellow,
        boxShadow: [
          BoxShadow(
            color: (isSpecial ? Colors.red : AppColors.yellow).withValues(alpha: 0.25),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        number.toString(),
        style: GoogleFonts.montserrat(
          color: isSpecial ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  String _formatFullDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      const days = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
      const months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
      final dayName = days[parsed.weekday - 1];
      final monthName = months[parsed.month - 1];
      return "$dayName, ${parsed.day} $monthName ${parsed.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _getStrategyDescription(String strategy) {
    switch (strategy) {
      case 'only_mine':
        return 'Usa únicamente los números que seleccionaste.';
      case 'variations':
        return 'Mantiene tus números y completa la combinación con otros válidos.';
      case 'balanced':
        return 'Combina tus números con otros valores de la lotería.';
      default:
        return 'Genera combinaciones según tus números.';
    }
  }
}
