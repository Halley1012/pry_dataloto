import 'package:flutter/material.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/styles/colores.dart';

/// Banner reutilizable para el patrón stale-while-revalidate.
///
/// Se muestra únicamente cuando ya existe una copia local útil, pero el
/// refresco remoto no pudo completarse. Nunca sustituye el contenido cacheado.
class AppStaleDataBanner extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry margin;

  const AppStaleDataBanner({
    super.key,
    this.message,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text =
        message ??
        l10n?.sinConexionDatos ??
        'Sin conexión · mostrando los últimos datos disponibles';

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.yellow,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado reutilizable para diferenciar un fallo de conexión de un estado vacío.
///
/// [isConnectionError] debe ser `true` sólo cuando la consulta remota falló y
/// no existe una copia local utilizable. Un 200 sin datos debe representarse
/// como estado vacío y no como un error de red.
class AppDataStateCard extends StatelessWidget {
  final bool isConnectionError;
  final VoidCallback? onRetry;
  final bool retrying;
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final bool useContainer;
  final double iconSize;

  const AppDataStateCard({
    super.key,
    required this.isConnectionError,
    this.onRetry,
    this.retrying = false,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon = Icons.insights_outlined,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    this.useContainer = true,
    this.iconSize = 46,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = isConnectionError
        ? (l10n?.errorConexion ?? 'Error de conexión')
        : (emptyTitle ??
              l10n?.informacionNoDisponible ??
              'Información no disponible');
    final body = isConnectionError
        ? (l10n?.datosLoteriaSinConexion ??
              'No pudimos actualizar los datos. Revisa tu conexión e inténtalo de nuevo.')
        : (emptyMessage ??
              l10n?.datosLoteriaNoDisponibles ??
              'Esta sección todavía no tiene información disponible.');

    final content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnectionError ? Icons.cloud_off_outlined : emptyIcon,
            size: iconSize,
            color: isConnectionError ? Colors.white54 : AppColors.yellow,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (isConnectionError && onRetry != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: retrying ? null : onRetry,
              icon: retrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n?.reintentar ?? 'Reintentar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.yellow,
                side: const BorderSide(color: AppColors.yellow),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!useContainer) {
      return Container(margin: margin, child: content);
    }

    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: content,
    );
  }
}
