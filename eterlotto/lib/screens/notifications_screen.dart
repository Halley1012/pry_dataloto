import 'package:flutter/material.dart';
import 'package:eterlotto/widgets/data_state_widgets.dart';
import 'package:provider/provider.dart';
import 'package:eterlotto/providers/notification_provider.dart';
import 'package:eterlotto/providers/subscription_provider.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import 'resultados_dashboard_screen.dart';

import '../utils/secure_storage_helper.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showBackButton;
  const NotificationsScreen({super.key, this.showBackButton = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilterIndex = 0;
  // 0: Mis loterías, 1: Mi País, 2: Internacionales
  String? _userPaisId;
  final _storage = AppSecureStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadUserCountry();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<NotificationProvider>();
      await provider.fetchNotifications();
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

  List<dynamic> _getFilteredNotifications(
    List<dynamic> allNotifications,
    NotificationProvider provider,
  ) {
    if (_selectedFilterIndex == 0) {
      // Mientras resolvemos las jugadas de la cuenta, no ocultamos alertas
      // por un instante. En cuanto llegan, este filtro queda exacto.
      if (!provider.playedRoutesResolved) return allNotifications;
      return allNotifications.where((notification) {
        final route = notification.loteriaRoute
            ?.toString()
            .trim()
            .toLowerCase();
        return route != null && provider.playedLotteryRoutes.contains(route);
      }).toList();
    } else if (_selectedFilterIndex == 1) {
      return allNotifications.where(_isNational).toList();
    } else if (_selectedFilterIndex == 2) {
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
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(
          l10n?.notificacionesIA ?? "Notificaciones",
          style: AppTextStyles.h2,
        ),
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.yellow),
        actions: [
          Consumer<SubscriptionProvider>(
            builder: (_, sub, __) => sub.isPremium
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: PremiumCrownIcon(isPremium: true, size: 19),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => provider.markAllAsRead(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
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
          if (provider.isLoading && !provider.hasCachedSnapshot) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            );
          }

          final filteredList = _getFilteredNotifications(
            provider.notifications,
            provider,
          );

          return SafeArea(
            child: RefreshIndicator(
              color: AppColors.yellow,
              backgroundColor: const Color(0xFF1E1E1E),
              displacement: 25.0,
              onRefresh: () => provider.fetchNotifications(force: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Los filtros forman parte del mismo scroll de las
                  // notificaciones. El AppBar permanece fijo, pero esta fila
                  // desaparece naturalmente al bajar por la lista.
                  SliverToBoxAdapter(
                    child: _buildFilterChips(),
                  ),
                  if (provider.showingStaleData ||
                      (provider.lastFetchFailed && provider.hasCachedSnapshot))
                    SliverToBoxAdapter(
                      child: _buildOfflineNotice(),
                    ),
                  if (provider.lastFetchFailed && !provider.hasCachedSnapshot)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildConnectionError(provider),
                    )
                  else if (provider.notifications.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_none,
                              size: 80,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilterIndex == 0
                                  ? _uiText('noPlayedNotifications')
                                  : _uiText('noNotifications'),
                              style: AppTextStyles.mensajeSecundario,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (filteredList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.filter_alt_off_outlined,
                              size: 60,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _emptyFilterMessage(),
                              style: AppTextStyles.mensajeSecundario,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final notification = filteredList[index];
                            return _buildNotificationCard(
                              context,
                              notification,
                              provider,
                            );
                          },
                          childCount: filteredList.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfflineNotice() {
    return const AppStaleDataBanner(
      margin: EdgeInsets.fromLTRB(16, 6, 16, 2),
    );
  }

  Widget _buildConnectionError(NotificationProvider provider) {
    return AppDataStateCard(
      isConnectionError: true,
      onRetry: () => provider.fetchNotifications(force: true),
      retrying: provider.isLoading,
      useContainer: false,
      margin: const EdgeInsets.all(20),
    );
  }

  String _uiText(String key) {
    final lang = Localizations.localeOf(context).languageCode;

    const values = {
      'es': {
        'myLotteries': 'Mis loterías',
        'myCountry': 'Mi País',
        'international': 'Internacionales',
        'noPlayedNotifications':
            'No tienes notificaciones de tus loterías jugadas aún',
        'noNotifications': 'No tienes notificaciones aún',
        'noMyLotteries': 'Sin notificaciones de tus loterías jugadas',
        'noMyCountry': 'Sin notificaciones para tu país',
        'noInternational': 'Sin notificaciones internacionales',
        'read': 'Leído',
        'delete': 'Eliminar',
      },
      'en': {
        'myLotteries': 'My lotteries',
        'myCountry': 'My country',
        'international': 'International',
        'noPlayedNotifications':
            'You do not have notifications from your played lotteries yet',
        'noNotifications': 'You do not have notifications yet',
        'noMyLotteries': 'No notifications from your played lotteries',
        'noMyCountry': 'No notifications for your country',
        'noInternational': 'No international notifications',
        'read': 'Read',
        'delete': 'Delete',
      },
      'pt': {
        'myLotteries': 'Minhas loterias',
        'myCountry': 'Meu país',
        'international': 'Internacionais',
        'noPlayedNotifications':
            'Você ainda não tem notificações das loterias que jogou',
        'noNotifications': 'Você ainda não tem notificações',
        'noMyLotteries': 'Sem notificações das loterias que você jogou',
        'noMyCountry': 'Sem notificações para o seu país',
        'noInternational': 'Sem notificações internacionais',
        'read': 'Lido',
        'delete': 'Excluir',
      },
    };

    return values[lang]?[key] ?? values['es']![key] ?? key;
  }

  String _emptyFilterMessage() {
    switch (_selectedFilterIndex) {
      case 0:
        return _uiText('noMyLotteries');
      case 1:
        return _uiText('noMyCountry');
      case 2:
        return _uiText('noInternational');
      default:
        return _uiText('noNotifications');
    }
  }

  Widget _buildFilterChips() {
    final filters = [
      _uiText('myLotteries'),
      _uiText('myCountry'),
      _uiText('international'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(
                        filters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.yellow,
                      backgroundColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color:
                              isSelected ? AppColors.yellow : Colors.white24,
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
            ),
          );
        },
      ),
    );
  }

  void _onNotificationTap(
    BuildContext context,
    dynamic notification,
    NotificationProvider provider,
  ) {
    if (!notification.leido) {
      provider.markAsRead(notification.id);
    }

    final loteriaNombre =
        (notification.loteriaNombre != null &&
            notification.loteriaNombre!.isNotEmpty)
        ? notification.loteriaNombre!
        : "Lotería";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosDashboardScreen(
          loteriaNombreInicial: loteriaNombre,
          loteriaRoute: notification.loteriaRoute,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, notification, provider) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final DateTime? fechaSorteoMostrar =
        notification.fechaSorteo ?? notification.createdAt;

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

    final card = Card(
      color: notification.leido
          ? const Color(0xFF1E1E1E)
          : const Color(0xFF252A34),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.leido
              ? Colors.transparent
              : AppColors.yellow.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onNotificationTap(context, notification, provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      _traducirMensajeNotificacion(
                        notification.mensaje ?? "",
                        localeCode,
                        fechaSorteoMostrar,
                      ),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat(
                            'dd MMM, yyyy • HH:mm',
                            localeCode,
                          ).format(notification.createdAt.toLocal()),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        if (!notification.leido)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.amber,
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

    return Dismissible(
      key: Key('notif_${notification.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.teal.shade800,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              _uiText('read'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _uiText('delete'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_outline, color: Colors.white, size: 26),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Deslizar a la derecha: Marcar como leído
          if (!notification.leido) {
            await provider.markAsRead(notification.id);
          }
          return false; // Mantiene la tarjeta en la lista
        } else if (direction == DismissDirection.endToStart) {
          // Deslizar a la izquierda: Eliminar notificación
          final deleted = await provider.deleteNotification(notification.id);
          return deleted; // Solo quita la tarjeta si el servidor la ocultó.
        }
        return false;
      },
      child: card,
    );
  }

  String _traducirMensajeNotificacion(
    String msj,
    String langCode,
    DateTime? fechaSorteo,
  ) {
    if (msj.isEmpty) return msj;

    String? fechaTexto;
    if (fechaSorteo != null) {
      if (langCode == 'en') {
        fechaTexto = DateFormat('MMM d').format(fechaSorteo);
      } else if (langCode == 'pt') {
        fechaTexto =
            "${fechaSorteo.day} de ${DateFormat('MMMM', 'pt').format(fechaSorteo)}";
      } else {
        fechaTexto =
            "${fechaSorteo.day} de ${DateFormat('MMMM', 'es').format(fechaSorteo)}";
      }
    }

    if (langCode == 'en') {
      // 1. "¡Casi! De los N números con mayor probabilidad generados por la IA para X, cayeron K números (LISTA)."
      final regCasi = RegExp(
        r"¡Casi! De los (\d+) números con mayor probabilidad generados por la IA para (.*?), cayeron (\d+) números \((.*?)\)\.",
      );
      if (regCasi.hasMatch(msj)) {
        return msj.replaceAllMapped(regCasi, (match) {
          final lot = match[2];
          final prefix = fechaTexto != null
              ? "In the $fechaTexto $lot draw, out"
              : "Out";
          return "Almost! $prefix of the ${match[1]} most probable numbers generated by the AI, ${match[3]} numbers matched (${match[4]}).";
        });
      }

      // 2. "En el sorteo de X, los N números más probables tuvieron una efectividad del P% (A de B aciertos)."
      final reg1 = RegExp(
        r"En el sorteo de (.*?), los (\d+) números más probables tuvieron una efectividad del (\d+)% \((\d+) de (\d+) aciertos\)\.",
      );
      if (reg1.hasMatch(msj)) {
        return msj.replaceAllMapped(reg1, (match) {
          final lot = match[1];
          final prefix = fechaTexto != null
              ? "In the $fechaTexto $lot draw"
              : "In the $lot draw";
          return "$prefix, the ${match[2]} most probable numbers achieved ${match[3]}% accuracy (${match[4]} out of ${match[5]} hits).";
        });
      }

      // 3. "¡La IA acertó la (balota especial|Superbalota) en el sorteo de hoy de X!"
      final reg2 = RegExp(
        r"¡La IA acertó la (?:balota especial|Superbalota) en el sorteo (?:de hoy )?de (.*?)!",
      );
      if (reg2.hasMatch(msj)) {
        return msj.replaceAllMapped(reg2, (match) {
          final lot = match[1];
          final drawStr = fechaTexto != null
              ? "the $fechaTexto $lot draw"
              : "today's $lot draw";
          return "The AI matched the special ball in $drawStr!";
        });
      }

      // 4. "¡La IA acertó N números en el sorteo de hoy de X!"
      final reg3 = RegExp(
        r"¡La IA acertó (\d+) números en el sorteo (?:de hoy )?de (.*?)!",
      );
      if (reg3.hasMatch(msj)) {
        return msj.replaceAllMapped(reg3, (match) {
          final lot = match[2];
          final drawStr = fechaTexto != null
              ? "the $fechaTexto $lot draw"
              : "today's $lot draw";
          return "The AI matched ${match[1]} numbers in $drawStr!";
        });
      }
    } else if (langCode == 'pt') {
      // 1. "¡Casi! De los N números con mayor probabilidad generados por la IA para X, cayeron K números (LISTA)."
      final regCasi = RegExp(
        r"¡Casi! De los (\d+) números con mayor probabilidad generados por la IA para (.*?), cayeron (\d+) números \((.*?)\)\.",
      );
      if (regCasi.hasMatch(msj)) {
        return msj.replaceAllMapped(regCasi, (match) {
          final lot = match[2];
          final prefix = fechaTexto != null
              ? "No sorteio de $fechaTexto do $lot, dos"
              : "Dos";
          return "Quase! $prefix ${match[1]} números com maior probabilidade gerados pela IA, saíram ${match[3]} números (${match[4]}).";
        });
      }

      // 2. "En el sorteo de X, los N números más probables tuvieron una efectividad del P% (A de B aciertos)."
      final reg1 = RegExp(
        r"En el sorteo de (.*?), los (\d+) números más probables tuvieron una efectividad del (\d+)% \((\d+) de (\d+) aciertos\)\.",
      );
      if (reg1.hasMatch(msj)) {
        return msj.replaceAllMapped(reg1, (match) {
          final lot = match[1];
          final prefix = fechaTexto != null
              ? "No sorteio de $fechaTexto do $lot"
              : "No sorteio do $lot";
          return "$prefix, os ${match[2]} números mais prováveis tiveram uma eficácia de ${match[3]}% (${match[4]} de ${match[5]} acertos).";
        });
      }

      // 3. "¡La IA acertó la (balota especial|Superbalota) en el sorteo de hoy de X!"
      final reg2 = RegExp(
        r"¡La IA acertó la (?:balota especial|Superbalota) en el sorteo (?:de hoy )?de (.*?)!",
      );
      if (reg2.hasMatch(msj)) {
        return msj.replaceAllMapped(reg2, (match) {
          final lot = match[1];
          final drawStr = fechaTexto != null
              ? "no sorteio de $fechaTexto do $lot"
              : "no sorteio de hoje do $lot";
          return "A IA acertou a bola especial $drawStr!";
        });
      }

      // 4. "¡La IA acertó N números en el sorteo de hoy de X!"
      final reg3 = RegExp(
        r"¡La IA acertó (\d+) números en el sorteo (?:de hoy )?de (.*?)!",
      );
      if (reg3.hasMatch(msj)) {
        return msj.replaceAllMapped(reg3, (match) {
          final lot = match[2];
          final drawStr = fechaTexto != null
              ? "no sorteio de $fechaTexto do $lot"
              : "no sorteio de hoje do $lot";
          return "A IA acertou ${match[1]} números $drawStr!";
        });
      }
    } else {
      // Español
      if (fechaTexto != null) {
        // 1. "¡Casi! De los N números con mayor probabilidad generados por la IA para X, cayeron K números (LISTA)."
        final regCasi = RegExp(
          r"¡Casi! De los (\d+) números con mayor probabilidad generados por la IA para (.*?), cayeron (\d+) números \((.*?)\)\.",
        );
        if (regCasi.hasMatch(msj)) {
          return msj.replaceAllMapped(
            regCasi,
            (match) =>
                "¡Casi! En el sorteo del $fechaTexto para ${match[2]}, de los ${match[1]} números con mayor probabilidad generados por la IA cayeron ${match[3]} números (${match[4]}).",
          );
        }

        // 2. "En el sorteo de X, los N números más probables..."
        final reg1 = RegExp(
          r"En el sorteo de (.*?), los (\d+) números más probables tuvieron una efectividad del (\d+)% \((\d+) de (\d+) aciertos\)\.",
        );
        if (reg1.hasMatch(msj)) {
          return msj.replaceAllMapped(
            reg1,
            (match) =>
                "En el sorteo del $fechaTexto para ${match[1]}, los ${match[2]} números más probables tuvieron una efectividad del ${match[3]}% (${match[4]} de ${match[5]} aciertos).",
          );
        }

        // 3. "¡La IA acertó la (balota especial|Superbalota) en el sorteo de hoy de X!"
        final reg2 = RegExp(
          r"¡La IA acertó la (?:balota especial|Superbalota) en el sorteo (?:de hoy )?de (.*?)!",
        );
        if (reg2.hasMatch(msj)) {
          return msj.replaceAllMapped(
            reg2,
            (match) =>
                "¡La IA acertó la balota especial en el sorteo del $fechaTexto para ${match[1]}!",
          );
        }

        // 4. "¡La IA acertó N números en el sorteo de hoy de X!"
        final reg3 = RegExp(
          r"¡La IA acertó (\d+) números en el sorteo (?:de hoy )?de (.*?)!",
        );
        if (reg3.hasMatch(msj)) {
          return msj.replaceAllMapped(
            reg3,
            (match) =>
                "¡La IA acertó ${match[1]} números en el sorteo del $fechaTexto para ${match[2]}!",
          );
        }
      }
    }

    return msj;
  }
}
