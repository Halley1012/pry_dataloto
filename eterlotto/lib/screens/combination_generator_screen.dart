import 'package:flutter/material.dart';
import 'package:eterlotto/widgets/data_state_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/providers/combination_generator_provider.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/utils/secure_storage_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/utils/pais_helper.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eterlotto/widgets/contenedor3.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _actionsOrderKey = 'combination_generator_actions_order_v1';
  static const List<String> _defaultActionOrder = [
    'generate',
    'select',
    'whatsapp',
    'delete',
    'save',
  ];

  final TextEditingController _inputController = TextEditingController();
  late CombinationGeneratorProvider _provider;
  List<String> _actionOrder = List<String>.from(_defaultActionOrder);

  @override
  void initState() {
    super.initState();
    _provider = CombinationGeneratorProvider();
    _loadActionOrder();
  }

  Future<void> _loadActionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_actionsOrderKey);

    if (saved == null || saved.isEmpty) return;

    // Migra órdenes anteriores (por ejemplo, cuando existía el botón PDF)
    // conservando la posición elegida por el usuario para las acciones vigentes.
    final migrated = saved
        .where(_defaultActionOrder.contains)
        .toList(growable: true);

    for (final action in _defaultActionOrder) {
      if (!migrated.contains(action)) {
        migrated.add(action);
      }
    }

    if (migrated.length != _defaultActionOrder.length) return;

    if (!mounted) return;
    setState(() {
      _actionOrder = migrated;
    });

    await prefs.setStringList(_actionsOrderKey, migrated);
  }

  Future<void> _saveActionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_actionsOrderKey, _actionOrder);
  }

  void _reorderActions(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _actionOrder.removeAt(oldIndex);
      _actionOrder.insert(newIndex, item);
    });

    _saveActionOrder();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _provider.dispose();
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
          backgroundColor: AppColors.blackfondo,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text('Eterlotto', style: AppTextStyles.h2),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.yellow,
              size: 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Consumer<SubscriptionProvider>(
              builder: (_, sub, __) => sub.isPremium
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: PremiumCrownIcon(isPremium: true, size: 19),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: Consumer<CombinationGeneratorProvider>(
          builder: (context, provider, child) {
            final l10n = AppLocalizations.of(context);
            provider.setLanguageCode(Localizations.localeOf(context).languageCode);

            // Si aún no hay datos, mostramos Skeleton en lugar de bloquear
            // toda la pantalla con un spinner.
            if (provider.isLoadingLotteries && provider.supportedLotteries.isEmpty) {
              return const _CombinationGeneratorSkeleton();
            }

            // Primer inicio sin red y sin una caché utilizable. A diferencia
            // del estado stale, aquí no hay información segura para mostrar.
            if (provider.supportedLotteries.isEmpty && provider.error != null) {
              return _buildLotteriesLoadFailure(provider.error!, provider);
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
                                                    : _t('Por definir', 'To be defined', 'A definir', 'À définir'),
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
                                l10n?.limpiar ?? "Limpiar",
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
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
                        subtitle: _t(
                          'Toca cualquier número que no quieras utilizar para excluirlo.',
                          'Tap any number you do not want to use to exclude it.',
                          'Toque em qualquer número que não queira usar para excluí-lo.',
                          'Touchez un numéro à exclure si vous ne voulez pas l’utiliser.',
                        ),
                        action: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _t(
                              '${provider.activeNumbers.length} de ${provider.detectedNumbers.length} activos',
                              '${provider.activeNumbers.length} of ${provider.detectedNumbers.length} active',
                              '${provider.activeNumbers.length} de ${provider.detectedNumbers.length} ativos',
                              '${provider.activeNumbers.length} sur ${provider.detectedNumbers.length} actifs',
                            ),
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
                                        l10n?.seGeneraranHasta(provider.quantity) ?? "Se generarán hasta ${provider.quantity}\ncombinaciones únicas.",
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
                                                Expanded(child: Text(l10n?.estrategiaSoloMisNumeros ?? 'Solo mis números', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'variations',
                                            child: Row(
                                              children: [
                                                const Text('✨', style: TextStyle(fontSize: 12)),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text(l10n?.estrategiaVariaciones ?? 'Variaciones', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'balanced',
                                            child: Row(
                                              children: [
                                                const Text('⚖️', style: TextStyle(fontSize: 12)),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text(l10n?.estrategiaEquilibradas ?? 'Equilibradas', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
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

                    // Acciones del generador. Mantener pulsado un botón permite
                    // cambiar su posición; el orden queda guardado localmente.
                    _buildGeneratedActions(provider),

                    if (provider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  provider.error!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Results ────────────────────────────────────────────
                    if (provider.combinations.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '${provider.combinations.length} ${l10n?.combinacionesGeneradas ?? 'combinaciones generadas'}',
                              style: AppTextStyles.h2.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectionSummary(provider.selectedCount),
                              style: AppTextStyles.caption.copyWith(
                                color: provider.hasSelectedCombinations
                                    ? AppColors.yellow
                                    : Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildGeneratedPlaysTable(provider),
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

  Widget _buildGeneratedActions(CombinationGeneratorProvider provider) {
    final hasCombinations = provider.combinations.isNotEmpty;
    final hasSelection = provider.hasSelectedCombinations;
    final allSelected =
        hasCombinations && provider.selectedCount == provider.combinations.length;

    return AppContainer3(
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _actionOrder.length,
            onReorder: _reorderActions,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.08).animate(animation),
                  child: child,
                ),
              );
            },
            itemBuilder: (context, index) {
              final action = _actionOrder[index];

              return ReorderableDelayedDragStartListener(
                key: ValueKey(action),
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: _buildGeneratorAction(
                    action,
                    provider,
                    hasCombinations: hasCombinations,
                    hasSelection: hasSelection,
                    allSelected: allSelected,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratorAction(
    String action,
    CombinationGeneratorProvider provider, {
    required bool hasCombinations,
    required bool hasSelection,
    required bool allSelected,
  }) {
    switch (action) {
      case 'generate':
        return _buildActionButton(
          icon: provider.isLoading ? null : Icons.auto_awesome,
          color: AppColors.yellow,
          enabled: !provider.isLoading,
          tooltip: provider.isLoading
              ? _t('Generando...', 'Generating...', 'Gerando...', 'Génération...')
              : _t(
                  'Generar combinaciones',
                  'Generate combinations',
                  'Gerar combinações',
                  'Générer des combinaisons',
                ),
          onPressed: provider.isLoading ? null : provider.generate,
          loading: provider.isLoading,
        );

      case 'select':
        return _buildActionButton(
          icon: allSelected ? Icons.deselect : Icons.check_circle_outline,
          color: AppColors.yellow,
          enabled: hasCombinations,
          tooltip: allSelected
              ? _t('Deseleccionar', 'Deselect all', 'Desmarcar', 'Tout désélectionner')
              : _t('Seleccionar todo', 'Select all', 'Selecionar tudo', 'Tout sélectionner'),
          onPressed:
              hasCombinations ? provider.toggleSelectAllCombinations : null,
        );

      case 'whatsapp':
        return _buildActionButton(
          icon: FontAwesomeIcons.whatsapp,
          color: const Color(0xFF25D366),
          enabled: hasSelection,
          tooltip: _t(
            'Compartir por WhatsApp',
            'Share via WhatsApp',
            'Compartilhar no WhatsApp',
            'Partager sur WhatsApp',
          ),
          onPressed:
              hasSelection ? () => _shareSelectedWhatsApp(provider) : null,
        );


      case 'delete':
        return _buildActionButton(
          icon: Icons.delete_outline,
          color: Colors.redAccent,
          enabled: hasCombinations,
          tooltip: hasSelection
              ? _t(
                  'Eliminar seleccionadas',
                  'Delete selected',
                  'Excluir selecionadas',
                  'Supprimer la sélection',
                )
              : _t('Limpiar lista', 'Clear list', 'Limpar lista', 'Vider la liste'),
          onPressed: hasCombinations ? () => _deleteGenerated(provider) : null,
        );

      case 'save':
        return _buildActionButton(
          icon: Icons.bookmark_add_outlined,
          color: AppColors.yellow,
          enabled: hasSelection,
          tooltip: _t('Guardar', 'Save', 'Salvar', 'Enregistrer'),
          onPressed:
              hasSelection ? () => _saveSelectedCombinations(provider) : null,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton({
    required dynamic icon,
    required Color color,
    required bool enabled,
    required String tooltip,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    final button = InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.45) : Colors.white10,
            width: 1.2,
          ),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.yellow,
                    strokeWidth: 2,
                  ),
                )
              : icon is IconData
                  ? Icon(
                      icon,
                      color: enabled ? color : Colors.white24,
                      size: 20,
                    )
                  : FaIcon(
                      icon,
                      color: enabled ? color : Colors.white24,
                      size: 19,
                    ),
        ),
      ),
    );

    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildGeneratedPlaysTable(CombinationGeneratorProvider provider) {
    final l10n = AppLocalizations.of(context);
    final combinations = provider.combinations;
    final date = provider.selectedLotteryRules?.proximoSorteo;
    final dateLabel = date == null || date.trim().isEmpty
        ? '--'
        : _formatFullDate(date);

    return Center(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12, width: 0.8),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '#',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 82,
                  child: Text(
                    l10n?.sorteoLabel ?? 'Sorteo',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n?.balotas ?? 'Balotas',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),
            ...List.generate(combinations.length, (index) {
              final combo = combinations[index];
              final selected = provider.isCombinationSelected(combo);
              final totalBalls = combo.mainNumbers.length + combo.specialNumbers.length;
              final ballSize = totalBalls <= 5
                  ? 32.0
                  : (totalBalls == 6 ? 30.0 : (totalBalls == 7 ? 27.0 : 24.0));
              final hPadding = totalBalls <= 5
                  ? 2.5
                  : (totalBalls == 6 ? 2.0 : (totalBalls == 7 ? 1.5 : 1.0));
              final color = _playRowColors[index % _playRowColors.length];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: EdgeInsets.only(
                  bottom: index == combinations.length - 1 ? 0 : 7,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.yellow.withValues(alpha: 0.08)
                      : color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppColors.yellow : Colors.white10,
                    width: selected ? 1.2 : 0.6,
                  ),
                ),
                child: InkWell(
                  onTap: () => provider.toggleCombinationSelection(combo),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: selected ? AppColors.yellow : Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 82,
                          child: Text(
                            dateLabel,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10.5,
                              color: selected ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final n in combo.mainNumbers)
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: hPadding),
                                      child: _build3DBall(
                                        n,
                                        baseColor: color,
                                        size: ballSize,
                                      ),
                                    ),
                                  if (combo.specialNumbers.isNotEmpty) ...[
                                    SizedBox(width: hPadding * 1.5),
                                    for (final n in combo.specialNumbers)
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: hPadding),
                                        child: _build3DBall(
                                          n,
                                          baseColor: const Color(0xFFB91C1C),
                                          size: ballSize,
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
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static const List<Color> _playRowColors = [
    Color(0xFF1E3A8A),
    Color(0xFF4C1D95),
    Color(0xFF0F766E),
    Color(0xFF9A3412),
    Color(0xFF065F46),
    Color(0xFF831843),
    Color(0xFF312E81),
    Color(0xFF155E75),
    Color(0xFF7C2D12),
    Color(0xFF78350F),
  ];

  Widget _build3DBall(
    int? numero, {
    Color baseColor = const Color(0xFFF33A21),
    double size = 32,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.75),
            baseColor.withValues(alpha: 0.5),
          ],
          center: Alignment.topLeft,
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Text(
          numero?.toString() ?? '–',
          style: AppTextStyles.caption.copyWith(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: numero != null ? Colors.white : Colors.white54,
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

  Future<void> _shareSelectedWhatsApp(
    CombinationGeneratorProvider provider,
  ) async {
    final selected = provider.combinations
        .where(provider.isCombinationSelected)
        .toList(growable: false);
    if (selected.isEmpty) return;

    final lotteryName = provider.selectedLotteryRules?.name ?? 'Eterlotto';
    final buffer = StringBuffer()
      ..writeln('🎲 $lotteryName - Eterlotto')
      ..writeln();

    for (var i = 0; i < selected.length; i++) {
      final combo = selected[i];
      final main = combo.mainNumbers.join(' - ');
      final special = combo.specialNumbers.isEmpty
          ? ''
          : ' | ${_t('Especial', 'Special', 'Especial', 'Spécial')}: ${combo.specialNumbers.join(' - ')}';
      buffer.writeln('${i + 1}. $main$special');
    }

    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteGenerated(
    CombinationGeneratorProvider provider,
  ) async {
    final selectedCount = provider.selectedCount;
    final deletingSelected = selectedCount > 0;
    final message = deletingSelected
        ? _t(
            '¿Eliminar $selectedCount jugada(s) seleccionada(s)?',
            'Delete $selectedCount selected play(s)?',
            'Excluir $selectedCount aposta(s) selecionada(s)?',
            'Supprimer $selectedCount grille(s) sélectionnée(s) ?',
          )
        : _t(
            '¿Limpiar todas las combinaciones generadas?',
            'Clear all generated combinations?',
            'Limpar todas as combinações geradas?',
            'Effacer toutes les combinaisons générées ?',
          );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          deletingSelected
              ? _t('Eliminar jugadas', 'Delete plays', 'Excluir apostas', 'Supprimer les grilles')
              : _t('Limpiar lista', 'Clear list', 'Limpar lista', 'Vider la liste'),
          style: AppTextStyles.h2.copyWith(color: Colors.white),
        ),
        content: Text(
          message,
          style: AppTextStyles.mensajeSecundario.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              _t('Cancelar', 'Cancel', 'Cancelar', 'Annuler'),
              style: AppTextStyles.caption.copyWith(color: AppColors.yellow),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _t('Eliminar', 'Delete', 'Excluir', 'Supprimer'),
              style: AppTextStyles.caption.copyWith(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (deletingSelected) {
      provider.removeSelectedCombinations();
    } else {
      provider.clearGeneratedCombinations();
    }
  }

  Widget _buildLotteriesLoadFailure(
    String message,
    CombinationGeneratorProvider provider,
  ) {
    return AppDataStateCard(
      isConnectionError: true,
      onRetry: provider.reload,
      retrying: provider.isLoadingLotteries,
      useContainer: false,
      margin: const EdgeInsets.all(20),
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
    return PaisHelper.getBanderaEmoji(country);
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
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }


  Future<void> _saveSelectedCombinations(
    CombinationGeneratorProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context);
    final storage = AppSecureStorage.instance;
    final userId = await storage.read(key: 'user_id');
    if (!mounted) return;

    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.debesIniciarSesionParaGuardar ??
                'Debes iniciar sesión para guardar',
            style: AppTextStyles.body.copyWith(fontSize: 12),
          ),
        ),
      );
      return;
    }

    final count = provider.selectedCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.guardando ?? 'Guardando...',
          style: AppTextStyles.body.copyWith(fontSize: 12),
        ),
        duration: const Duration(milliseconds: 700),
      ),
    );

    final success = await provider.saveSelected(userId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? _savedSelectionMessage(count)
              : (l10n?.errorAlGuardarJugadas ??
                    'Hubo un error al guardar algunas jugadas'),
          style: AppTextStyles.body.copyWith(fontSize: 12),
        ),
        backgroundColor:
            success ? Colors.green.shade800 : Colors.red.shade800,
      ),
    );
  }

  String _t(String es, String en, String pt, String fr) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => en,
      'pt' => pt,
      'fr' => fr,
      _ => es,
    };
  }

  String _selectionSummary(int count) {
    final lang = Localizations.localeOf(context).languageCode;
    if (count == 0) {
      return switch (lang) {
        'en' => 'Tap one or more plays to select them',
        'pt' => 'Toque em uma ou mais apostas para selecioná-las',
        'fr' => 'Touchez une ou plusieurs grilles pour les sélectionner',
        _ => 'Toca una o varias jugadas para seleccionarlas',
      };
    }
    return switch (lang) {
      'en' => '$count selected',
      'pt' => '$count selecionada${count == 1 ? '' : 's'}',
      'fr' => '$count sélectionnée${count == 1 ? '' : 's'}',
      _ => '$count seleccionada${count == 1 ? '' : 's'}',
    };
  }

  String _saveSelectionLabel(int count) {
    final lang = Localizations.localeOf(context).languageCode;
    if (count == 0) {
      return switch (lang) {
        'en' => 'SELECT PLAYS TO SAVE',
        'pt' => 'SELECIONE APOSTAS PARA SALVAR',
        'fr' => 'SÉLECTIONNEZ DES GRILLES',
        _ => 'SELECCIONA JUGADAS PARA GUARDAR',
      };
    }
    if (count == 1) {
      return switch (lang) {
        'en' => 'SAVE PLAY',
        'pt' => 'SALVAR APOSTA',
        'fr' => 'ENREGISTRER LA GRILLE',
        _ => 'GUARDAR JUGADA',
      };
    }
    return switch (lang) {
      'en' => 'SAVE $count PLAYS',
      'pt' => 'SALVAR $count APOSTAS',
      'fr' => 'ENREGISTRER $count GRILLES',
      _ => 'GUARDAR $count JUGADAS',
    };
  }

  String _clearSelectionLabel() {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => 'Clear',
      'pt' => 'Limpar',
      'fr' => 'Effacer',
      _ => 'Limpiar',
    };
  }

  String _savedSelectionMessage(int count) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => count == 1 ? 'Play saved successfully' : '$count plays saved successfully',
      'pt' => count == 1 ? 'Aposta salva com sucesso' : '$count apostas salvas com sucesso',
      'fr' => count == 1 ? 'Grille enregistrée avec succès' : '$count grilles enregistrées avec succès',
      _ => count == 1 ? 'Jugada guardada con éxito' : '$count jugadas guardadas con éxito',
    };
  }

  String _formatFullDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      final locale = Localizations.localeOf(context).languageCode;
      return DateFormat('EEE, d MMM yyyy', locale).format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _getStrategyDescription(String strategy) {
    final l10n = AppLocalizations.of(context);
    switch (strategy) {
      case 'only_mine':
        return l10n?.descEstrategiaSoloMis ?? 'Usa únicamente los números que seleccionaste.';
      case 'variations':
        return l10n?.descEstrategiaVariaciones ?? 'Mantiene tus números y completa la combinación con otros válidos.';
      case 'balanced':
        return l10n?.descEstrategiaBalanced ?? 'Combina tus números con otros valores de la lotería.';
      default:
        return l10n?.descEstrategiaDefault ?? 'Genera combinaciones según tus números.';
    }
  }
}
