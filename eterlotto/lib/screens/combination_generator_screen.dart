import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eterlotto/providers/combination_generator_provider.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/utils/secure_storage_helper.dart';

class CombinationGeneratorScreen extends StatefulWidget {
  const CombinationGeneratorScreen({super.key});

  @override
  State<CombinationGeneratorScreen> createState() => _CombinationGeneratorScreenState();
}

class _CombinationGeneratorScreenState extends State<CombinationGeneratorScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CombinationGeneratorProvider(),
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
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title section
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: AppColors.yellow.withOpacity(0.2),
                        ),
                        child: const Icon(Icons.casino, color: AppColors.yellow, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Genera tus propias combinaciones",
                              style: AppTextStyles.h2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Usa tus números favoritos (fechas, edades, etc.) y crea hasta 10 jugadas personalizadas.",
                              style: TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Lottery Selection
                  _buildSectionContainer(
                    title: "Selecciona la lotería",
                    icon: Icons.emoji_events,
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: provider.selectedLottery,
                            dropdownColor: AppColors.darkGray,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.darkGray,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            style: const TextStyle(color: Colors.white),
                            items: provider.supportedLotteries.map((rule) {
                              // Capitalize first letter
                              String name = rule.lotteryId;
                              if (name.isNotEmpty) {
                                name = name[0].toUpperCase() + name.substring(1);
                              }
                              return DropdownMenuItem(
                                value: rule.lotteryId, 
                                child: Text(name)
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) provider.setLottery(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Rules info
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.yellow.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.yellow.withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info, color: AppColors.yellow, size: 16),
                                    const SizedBox(width: 4),
                                    const Text("Reglas de esta lotería", style: TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.selectedLotteryRules?.rulesDescription ?? "Cargando reglas...",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Input Numbers
                  _buildSectionContainer(
                    title: "Tus números",
                    subtitle: "Ingresa números, una fecha o valores que tengan significado para ti.",
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
                              borderSide: BorderSide(color: AppColors.yellow.withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.yellow.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.yellow),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54),
                              onPressed: () {
                                _inputController.clear();
                                provider.setInputData("");
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text("Ejemplo: 12/10/1986, 7 14 21, 100, etc.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 16),
                        
                        if (provider.detectedNumbers.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppColors.yellow, size: 16),
                              const SizedBox(width: 4),
                              const Text("Números detectados", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: provider.detectedNumbers.map((num) => _buildBalota(num, isSpecial: false)).toList(),
                          )
                        ]
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildSectionContainer(
                          title: "Cantidad de jugadas",
                          subtitle: "Selecciona cuántas combinaciones generar.",
                          icon: Icons.numbers,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: AppColors.yellow),
                                onPressed: provider.decrementQuantity,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.darkGray,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text("${provider.quantity}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: AppColors.yellow),
                                onPressed: provider.incrementQuantity,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSectionContainer(
                          title: "Estrategia",
                          subtitle: "Usa tus números como base y agrega variaciones.",
                          icon: Icons.settings,
                          child: DropdownButtonFormField<String>(
                            value: provider.strategy,
                            dropdownColor: AppColors.darkGray,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.darkGray,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: const [
                              DropdownMenuItem(value: 'balanced', child: Text('Equilibrada')),
                              DropdownMenuItem(value: 'random', child: Text('Aleatoria')),
                            ],
                            onChanged: (val) {
                              if (val != null) provider.setStrategy(val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading ? null : () => provider.generate(),
                      icon: provider.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.black),
                      label: Text(
                        provider.isLoading ? "GENERANDO..." : "GENERAR COMBINACIONES",
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(provider.error!, style: const TextStyle(color: Colors.red)),
                    ),
                    
                  if (provider.combinations.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.list, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text("${provider.combinations.length} combinaciones generadas", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () => provider.generate(),
                          icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
                          label: const Text("Generar otras", style: TextStyle(color: Colors.white70)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2, // Adjust aspect ratio to fit the combination
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: provider.combinations.length,
                      itemBuilder: (context, index) {
                        final combo = provider.combinations[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.darkGray,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Text("#${combo.number}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Wrap(
                                  spacing: 2,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.center,
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                           final storage = AppSecureStorage.instance;
                           final userId = await storage.read(key: "user_id");
                           if (userId != null) {
                             if (!context.mounted) return;
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardando...')));
                             final success = await provider.saveAll(userId);
                             if (!context.mounted) return;
                             if (success) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jugadas guardadas con éxito')));
                             } else {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hubo un error al guardar algunas jugadas')));
                             }
                           } else {
                             if (!context.mounted) return;
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para guardar')));
                           }
                        },
                        icon: const Icon(Icons.save, color: Colors.black),
                        label: const Text("Guardar todas", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.yellow,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required String title, String? subtitle, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: AppColors.yellow, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          const SizedBox(height: 16),
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
            color: (isSpecial ? Colors.red : AppColors.yellow).withOpacity(0.4),
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
          fontSize: 14,
        ),
      ),
    );
  }
  
  Widget _buildMiniBalota(int number, bool isSpecial) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSpecial ? Colors.red : AppColors.yellow,
      ),
      child: Text(
        number.toString(),
        style: TextStyle(
          color: isSpecial ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
