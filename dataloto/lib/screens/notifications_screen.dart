import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dataloto/providers/notification_provider.dart';
import 'package:dataloto/styles/colores.dart';
import 'package:dataloto/styles/app_text_styles.dart';
import 'package:dataloto/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import 'baloto.dart';
import 'miloto.dart';
import 'color_loto.dart';
import 'powerball.dart';
import 'lotto_america.dart';
import 'double_play.dart';
import 'millionaire_life.dart';
import 'megamillions.dart';
import 'estadisticas_bloto.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilterIndex = 0; // 0: Mi País, 1: Internacionales, 2: Todas
  String? _userPaisId;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadUserCountry();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<NotificationProvider>();
      await provider.fetchNotifications();
      await provider.markAllAsRead();
    });
  }

  Future<void> _loadUserCountry() async {
    final pId = await _storage.read(key: 'pais_id');
    if (mounted) {
      setState(() {
        _userPaisId = pId;
      });
    }
  }

  bool _isNational(dynamic notification) {
    if (notification.paisId == null) return false;
    return notification.paisId.toString() == _userPaisId;
  }

  bool _isInternational(dynamic notification) {
    return !_isNational(notification);
  }

  List<dynamic> _getFilteredNotifications(List<dynamic> allNotifications) {
    if (_selectedFilterIndex == 0) {
      return allNotifications.where(_isNational).toList();
    } else if (_selectedFilterIndex == 1) {
      return allNotifications.where(_isInternational).toList();
    }
    return allNotifications;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.blackfondo,
      appBar: AppBar(
        title: Text(l10n?.notificacionesIA ?? "Notificaciones", style: AppTextStyles.h2),
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.yellow),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => provider.markAllAsRead(),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: Text(
                  l10n?.marcarTodoComoLeido ?? "Marcar todo como leído",
                  style: const TextStyle(
                    color: AppColors.yellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
          }

          final filteredList = _getFilteredNotifications(provider.notifications);

          return Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: provider.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_none, size: 80, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)?.sinNotificaciones ?? "No tienes notificaciones aún", style: AppTextStyles.mensajeSecundario),
                          ],
                        ),
                      )
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.filter_alt_off_outlined, size: 60, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)?.sinNotificacionesCategoria ?? "Sin notificaciones para tu país",
                                  style: AppTextStyles.mensajeSecundario,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => setState(() => _selectedFilterIndex = 2),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    foregroundColor: AppColors.yellow,
                                  ),
                                  child: Text(AppLocalizations.of(context)?.verTodasNotificaciones ?? "Ver todas las notificaciones"),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchNotifications(),
                            color: AppColors.yellow,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final notification = filteredList[index];
                                return _buildNotificationCard(context, notification, provider);
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final l10n = AppLocalizations.of(context);
    final filters = [
      l10n?.miPais ?? "Mi País",
      l10n?.internacionales ?? "Internacionales",
      l10n?.todas ?? "Todas"
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                filters[index],
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.yellow,
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.yellow : Colors.white12,
                ),
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilterIndex = index);
                }
              },
            ),
          );
        }),
      ),
    );
  }

  void _onNotificationTap(BuildContext context, dynamic notification, dynamic provider) {
    if (!notification.leido) {
      provider.markAsRead(notification.id);
    }

    final msj = (notification.mensaje ?? "").toString().toLowerCase();

    if (msj.contains("baloto")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BalotoScreen()));
    } else if (msj.contains("miloto")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MilotoScreen()));
    } else if (msj.contains("colorloto")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ColorLotoScreen()));
    } else if (msj.contains("powerball")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerballScreen()));
    } else if (msj.contains("lotto america")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LottoAmericaScreen()));
    } else if (msj.contains("double play")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DoublePlayScreen()));
    } else if (msj.contains("millionaire")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MillionaireLifeScreen()));
    } else if (msj.contains("mega millions")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MegaMillionsScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EstadisticasBlotoScreen()));
    }
  }

  Widget _buildNotificationCard(BuildContext context, notification, provider) {
    IconData icon;
    Color iconColor;

    switch (notification.tipo) {
      case 'acierto_directo':
        icon = Icons.auto_awesome;
        iconColor = Colors.amber;
        break;
      case 'acierto_parcial':
        icon = Icons.insights;
        iconColor = Colors.greenAccent;
        break;
      case 'precision':
        icon = Icons.analytics_outlined;
        iconColor = Colors.blueAccent;
        break;
      default:
        icon = Icons.notifications_none_outlined;
        iconColor = AppColors.yellow;
    }

    return Card(
      color: notification.leido ? const Color(0xFF1E1E1E) : const Color(0xFF252A34),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.leido ? Colors.transparent : AppColors.yellow.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onNotificationTap(context, notification, provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _traducirMensajeNotificacion(notification.mensaje ?? "", Localizations.localeOf(context).languageCode),
                      style: AppTextStyles.mensajeSecundario.copyWith(
                        color: Colors.white,
                        fontWeight: notification.leido ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM, yyyy', Localizations.localeOf(context).languageCode).format(notification.createdAt),
                          style: AppTextStyles.caption.copyWith(color: Colors.white54),
                        ),
                        if (!notification.leido)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _traducirMensajeNotificacion(String msj, String langCode) {
    if (msj.isEmpty) return msj;

    if (langCode == 'en') {
      // 1. "¡Casi! De los N números con mayor probabilidad generados por la IA para X, cayeron K números (LISTA)."
      final regCasi = RegExp(r"¡Casi! De los (\d+) números con mayor probabilidad generados por la IA para (.*?), cayeron (\d+) números \((.*?)\)\.");
      if (regCasi.hasMatch(msj)) {
        return msj.replaceAllMapped(regCasi, (match) => "Almost! Out of the ${match[1]} most probable numbers generated by the AI for ${match[2]}, ${match[3]} numbers matched (${match[4]}).");
      }

      // 2. "En el sorteo de X, los N números más probables tuvieron una efectividad del P% (A de B aciertos)."
      final reg1 = RegExp(r"En el sorteo de (.*?), los (\d+) números más probables tuvieron una efectividad del (\d+)% \((\d+) de (\d+) aciertos\)\.");
      if (reg1.hasMatch(msj)) {
        return msj.replaceAllMapped(reg1, (match) => "In the ${match[1]} draw, the ${match[2]} most probable numbers achieved ${match[3]}% accuracy (${match[4]} out of ${match[5]} hits).");
      }

      // 3. "¡La IA acertó la (balota especial|Superbalota) en el sorteo de hoy de X!"
      final reg2 = RegExp(r"¡La IA acertó la (?:balota especial|Superbalota) en el sorteo de hoy de (.*?)!");
      if (reg2.hasMatch(msj)) {
        return msj.replaceAllMapped(reg2, (match) => "The AI matched the special ball in today's ${match[1]} draw!");
      }

      // 4. "¡La IA acertó N números en el sorteo de hoy de X!"
      final reg3 = RegExp(r"¡La IA acertó (\d+) números en el sorteo de hoy de (.*?)!");
      if (reg3.hasMatch(msj)) {
        return msj.replaceAllMapped(reg3, (match) => "The AI matched ${match[1]} numbers in today's ${match[2]} draw!");
      }
    } else if (langCode == 'pt') {
      // 1. "¡Casi! De los N números con mayor probabilidad generados por la IA para X, cayeron K números (LISTA)."
      final regCasi = RegExp(r"¡Casi! De los (\d+) números con mayor probabilidad generados por la IA para (.*?), cayeron (\d+) números \((.*?)\)\.");
      if (regCasi.hasMatch(msj)) {
        return msj.replaceAllMapped(regCasi, (match) => "Quase! Dos ${match[1]} números com maior probabilidade gerados pela IA para ${match[2]}, saíram ${match[3]} números (${match[4]}).");
      }

      // 2. "En el sorteo de X, los N números más probables tuvieron una efectividad del P% (A de B aciertos)."
      final reg1 = RegExp(r"En el sorteo de (.*?), los (\d+) números más probables tuvieron una efectividad del (\d+)% \((\d+) de (\d+) aciertos\)\.");
      if (reg1.hasMatch(msj)) {
        return msj.replaceAllMapped(reg1, (match) => "No sorteio do ${match[1]}, os ${match[2]} números mais prováveis tiveram uma eficácia de ${match[3]}% (${match[4]} de ${match[5]} acertos).");
      }

      // 3. "¡La IA acertó la (balota especial|Superbalota) en el sorteo de hoy de X!"
      final reg2 = RegExp(r"¡La IA acertó la (?:balota especial|Superbalota) en el sorteo de hoy de (.*?)!");
      if (reg2.hasMatch(msj)) {
        return msj.replaceAllMapped(reg2, (match) => "A IA acertou a bola especial no sorteio de hoje do ${match[1]}!");
      }

      // 4. "¡La IA acertó N números en el sorteo de hoy de X!"
      final reg3 = RegExp(r"¡La IA acertó (\d+) números en el sorteo de hoy de (.*?)!");
      if (reg3.hasMatch(msj)) {
        return msj.replaceAllMapped(reg3, (match) => "A IA acertou ${match[1]} números no sorteio de hoje do ${match[2]}!");
      }
    }

    return msj;
  }
}
