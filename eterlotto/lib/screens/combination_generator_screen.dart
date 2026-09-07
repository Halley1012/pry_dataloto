import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/providers/combination_generator_provider.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/utils/secure_storage_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

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
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white70),
              onPressed: () {},
            )
          ],
        ),
        body: Consumer<CombinationGeneratorProvider>(
          builder: (context, provider, child) {
            final l10n = AppLocalizations.of(context);

            // Show full-screen loader while lotteries are being fetched for the first time
            if (provider.isLoadingLotteries) {
              return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
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
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
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
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: provider.selectedLottery,
                                  dropdownColor: AppColors.darkGray,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.darkGray,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  items: provider.supportedLotteries.map((rule) {
                                    final name = rule.lotteryId.isNotEmpty
                                        ? rule.lotteryId[0].toUpperCase() + rule.lotteryId.substring(1)
                                        : rule.lotteryId;
                                    return DropdownMenuItem(
                                      value: rule.lotteryId,
                                      child: Text(name),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) provider.setLottery(val);
                                  },
                                ),
                              ),
                              if (provider.selectedLotteryRules?.proximoSorteo != null) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        l10n?.proximoSorteo ?? "Próximo sorteo",
                                        style: const TextStyle(color: Colors.white38, fontSize: 9),
                                        textAlign: TextAlign.end,
                                      ),
                                      Text(
                                        _formatShortDate(provider.selectedLotteryRules!.proximoSorteo!),
                                        style: const TextStyle(
                                          color: AppColors.yellow,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Rules badge below the dropdown
                          if (provider.selectedLotteryRules != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.yellow.withValues(alpha: 0.1),
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
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              l10n?.cargandoReglas ?? "Cargando reglas...",
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Input Numbers ──────────────────────────────────────
                    _buildSectionContainer(
                      title: l10n?.tusNumeros ?? "Tus números",
                      subtitle: l10n?.ingresaNumerosFecha ?? "Ingresa números, una fecha o valores significativos.",
                      icon: Icons.person,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _inputController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: provider.setInputData,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.darkGray,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.yellow.withValues(alpha: 0.5)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.yellow.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.yellow),
                              ),
                              hintText: l10n?.ejemploNumeros ?? "Ej: 12/10/1986, 7 14 21...",
                              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54),
                                onPressed: () {
                                  _inputController.clear();
                                  provider.setInputData("");
                                },
                              ),
                            ),
                          ),
                          if (provider.detectedNumbers.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: AppColors.yellow, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  l10n?.numerosDetectados ?? "Números detectados",
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: provider.detectedNumbers
                                  .map((n) => _buildBalota(n, isSpecial: false))
                                  .toList(),
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Quantity + Strategy ───────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSectionContainer(
                            title: l10n?.cantidadDeJugadas ?? "Cantidad",
                            icon: Icons.numbers,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildCounterBtn(Icons.remove, provider.decrementQuantity),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGray,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${provider.quantity}",
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildCounterBtn(Icons.add, provider.incrementQuantity),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSectionContainer(
                            title: l10n?.estrategia ?? "Estrategia",
                            icon: Icons.tune,
                            child: DropdownButtonFormField<String>(
                              value: provider.strategy,
                              isExpanded: true,
                              dropdownColor: AppColors.darkGray,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.darkGray,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: [
                                DropdownMenuItem(value: 'balanced', child: Text(l10n?.estrategiaEquilibrada ?? 'Equilibrada')),
                                DropdownMenuItem(value: 'random', child: Text(l10n?.estrategiaAleatoria ?? 'Aleatoria')),
                              ],
                              onChanged: (val) {
                                if (val != null) provider.setStrategy(val);
                              },
                            ),
                          ),
                        ),
                      ],
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
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
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
                              Expanded(child: Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
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
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => provider.generate(),
                            icon: const Icon(Icons.refresh, color: Colors.white60, size: 16),
                            label: Text(l10n?.generarOtras ?? "Generar otras", style: const TextStyle(color: Colors.white60, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Combinations list — vertical, one per row for clarity
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
                              color: AppColors.darkGray,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    "#${combo.number}",
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ),
                                Expanded(
                                  child: Wrap(
                                    spacing: 5,
                                    runSpacing: 5,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      ...combo.mainNumbers.map((n) => _buildMiniBalota(n, false)),
                                      if (combo.specialNumber != null)
                                        _buildMiniBalota(combo.specialNumber!, true),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final storage = AppSecureStorage.instance;
                            final userId = await storage.read(key: "user_id");
                            final l10nInner = AppLocalizations.of(context);
                            if (userId != null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10nInner?.guardando ?? 'Guardando...')),
                              );
                              final success = await provider.saveAll(userId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? (l10nInner?.jugadasGuardadasConExito ?? 'Jugadas guardadas con éxito')
                                      : (l10nInner?.errorAlGuardarJugadas ?? 'Hubo un error al guardar algunas jugadas')),
                                  backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              );
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n?.debesIniciarSesionParaGuardar ?? 'Debes iniciar sesión para guardar')),
                              );
                            }
                          },
                          icon: const Icon(Icons.save_alt_rounded, color: Colors.black),
                          label: Text(
                            l10n?.guardarTodas ?? "Guardar todas",
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildCounterBtn(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.yellow.withValues(alpha: 0.15),
          border: Border.all(color: AppColors.yellow.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: AppColors.yellow, size: 18),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.yellow, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBalota(int number, {bool isSpecial = false}) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSpecial ? Colors.red : AppColors.yellow,
        boxShadow: [
          BoxShadow(
            color: (isSpecial ? Colors.red : AppColors.yellow).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        number.toString(),
        style: TextStyle(
          color: isSpecial ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
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
        style: TextStyle(
          color: isSpecial ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  String _formatShortDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      final months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
      return "${parsed.day} ${months[parsed.month - 1]}";
    } catch (_) {
      return dateStr;
    }
  }
}
