import 'package:eterlotto/screens/loteria_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/styles/colores.dart';
import 'package:eterlotto/styles/app_text_styles.dart';
import 'package:eterlotto/widgets/lottery_avatar_3d.dart';
import 'package:eterlotto/utils/pais_helper.dart';
import 'package:eterlotto/l10n/generated/app_localizations.dart';

class LoteriasPais extends StatefulWidget {
  const LoteriasPais({super.key});

  @override
  State<LoteriasPais> createState() => _LoteriasPaisState();
}

class _LoteriasPaisState extends State<LoteriasPais> {

  List<Map<String, dynamic>> _loterias = [];
  List<Map<String, dynamic>> _filteredLoterias = [];
  List<Map<String, dynamic>> _paises = [];
  final TextEditingController _searchController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  String? _userCountry;

  bool _isLoading = true;
  bool _isShowingAll = false;

  @override
  void initState() {
    super.initState();
    _cargarExplorarMundial();
  }

  Future<void> _cargarExplorarMundial() async {
    if (!mounted) return;

    // ⚡ 1. Mostrar caché al instante (0 ms)
    final cached = await CacheService.getJson('explorar_loterias_mundial');
    final cachedPaises = await CacheService.getJson('paises_list_cache');
    final uCountry = await _storage.read(key: 'pais_nombre');

    if (cached != null && mounted) {
      setState(() {
        _userCountry = uCountry;
        _loterias = List<Map<String, dynamic>>.from(cached);
        _filteredLoterias = List<Map<String, dynamic>>.from(_loterias);
        if (cachedPaises != null) {
          _paises = List<Map<String, dynamic>>.from(cachedPaises);
        }
        _isLoading = false;
      });
    }

    if (_loterias.isEmpty) setState(() => _isLoading = true);

    try {
      // ⚡ Cargar países y todas las loterías de forma ultra rápida en 1 sola petición
      final results = await Future.wait([
        ApiService.getPaises().catchError((_) => <Map<String, dynamic>>[]),
        ApiService.getAllLoterias().catchError((e) {
          debugPrint("Error cargando todas las loterías: $e");
          return <dynamic>[];
        }),
      ]);

      final paisesRaw = results[0] as List<Map<String, dynamic>>;
      if (paisesRaw.isNotEmpty) {
        _paises = paisesRaw;
        CacheService.setJson('paises_list_cache', _paises);
      }

      final loteriasRaw = results[1];
      final List<Map<String, dynamic>> todas = loteriasRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (mounted) {
        setState(() {
          _userCountry = uCountry;
          _loterias = todas;
          _filteredLoterias = todas;
          _isLoading = false;
        });
        if (todas.isNotEmpty) {
          CacheService.setJson('explorar_loterias_mundial', todas);
        }
      }
    } catch (e) {
      debugPrint("❌ Error crítico en Explorar Mundial: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        _filteredLoterias = _loterias;
      } else {
        _filteredLoterias = _loterias.where((l) {
          final name = (l["nombre"] ?? "").toString().toLowerCase();
          final pNombre = _getPaisNombre(l["pais_id"]).toLowerCase();
          return name.contains(q) || pNombre.contains(q);
        }).toList();
      }
    });
  }

  List<Map<String, dynamic>> _getDisplayList() {
    if (_searchController.text.trim().isNotEmpty) {
      return _filteredLoterias;
    }
    
    if (_isShowingAll) {
      return _filteredLoterias;
    }

    final Map<String, int> countsPerCountry = {};
    final List<Map<String, dynamic>> limitedList = [];

    for (var loteria in _filteredLoterias) {
      final pId = loteria["pais_id"]?.toString() ?? "unknown";
      final currentCount = countsPerCountry[pId] ?? 0;

      if (currentCount < 2) {
        limitedList.add(loteria);
        countsPerCountry[pId] = currentCount + 1;
      }
    }

    return limitedList;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.yellow,
          onRefresh: _cargarExplorarMundial,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text(
                  l10n?.explorarLoterias ?? "Explorar Loterías",
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              _buildSearchBar(l10n),
              Expanded(
                child: _isLoading && _loterias.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                  : _buildLotteryList(l10n),
              ),
              _buildFooterButton(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n?.buscarLoteriaOPais ?? "Buscar lotería o país...",
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildLotteryList(AppLocalizations? l10n) {
    final displayList = _getDisplayList();
    final grouped = <String, List<Map<String, dynamic>>>{};
    final langCode = Localizations.localeOf(context).languageCode;

    for (var lot in displayList) {
      final pNombre = _getPaisNombre(lot["pais_id"]);
      grouped.putIfAbsent(pNombre, () => []).add(lot);
    }

    final sortedCountries = grouped.keys.toList()
      ..sort((a, b) {
        if (a == _userCountry) return -1;
        if (b == _userCountry) return 1;
        return a.compareTo(b);
      });

    return ListView.builder(
      itemCount: sortedCountries.length,
      itemBuilder: (context, i) {
        final country = sortedCountries[i];
        final lots = grouped[country]!;
        final countryDisplay = PaisHelper.getNombreTraducido(country, langCode);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Text(PaisHelper.getBanderaEmoji(country), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    countryDisplay,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ...lots.map((loteria) => _buildExploreItem(loteria, l10n)),
          ],
        );
      },
    );
  }

  Widget _buildExploreItem(Map<String, dynamic> loteria, AppLocalizations? l10n) {
    final nombre = loteria["nombre"] ?? "";
    final bool hasProximo = loteria["proximo_sorteo"] != null &&
        loteria["proximo_sorteo"].toString().isNotEmpty &&
        loteria["proximo_sorteo"].toString() != "null";
    final rawFecha = hasProximo
        ? loteria["proximo_sorteo"]
        : (loteria["fecha"] ?? loteria["ultimo_sorteo"]);
    final fechaDisplay = _formatearFechaProximo(rawFecha?.toString());
    final estadoDisplay = _calcularEstadoSorteo(rawFecha?.toString());
    final String labelTitulo = hasProximo
        ? (l10n?.proximoSorteo ?? "Próximo sorteo")
        : (l10n?.ultimoSorteo ?? "Último sorteo");
    final String nombreFormateado = nombre.isNotEmpty
        ? nombre[0].toUpperCase() + nombre.substring(1).toLowerCase()
        : "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _resolveScreen(loteria))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LotteryAvatar3D(nombre: nombre, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombreFormateado,
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    labelTitulo,
                    style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    fechaDisplay,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (estadoDisplay.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      estadoDisplay,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.star_outline,
                color: AppColors.yellow,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFechaProximo(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "Próximo sorteo";
    try {
      final clean = fecha.trim();
      final parsed = DateTime.tryParse(clean) ?? (clean.length >= 10 ? DateTime.tryParse(clean.substring(0, 10)) : null);
      if (parsed == null) return fecha;

      final langCode = Localizations.localeOf(context).languageCode;
      final dias = langCode == 'en' 
          ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
          : (langCode == 'pt' 
              ? ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
              : ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]);

      final meses = langCode == 'en'
          ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
          : (langCode == 'pt'
              ? ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
              : ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]);

      final diaSemana = dias[parsed.weekday - 1];
      final mes = meses[parsed.month - 1];

      return "$diaSemana, ${parsed.day} $mes ${parsed.year}";
    } catch (_) {
      return fecha;
    }
  }

  String _calcularEstadoSorteo(String? fecha) {
    if (fecha == null || fecha.isEmpty) return "";
    try {
      final clean = fecha.trim();
      final parsed = DateTime.tryParse(clean) ?? (clean.length >= 10 ? DateTime.tryParse(clean.substring(0, 10)) : null);
      if (parsed == null) return "";

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(parsed.year, parsed.month, parsed.day);
      final diff = target.difference(today).inDays;

      final langCode = Localizations.localeOf(context).languageCode;

      if (diff == 0) {
        return langCode == 'en' ? "Draws today" : (langCode == 'pt' ? "Sorteia hoje" : "Sortea hoy");
      } else if (diff == 1) {
        return langCode == 'en' ? "Tomorrow" : (langCode == 'pt' ? "Amanhã" : "Mañana");
      } else if (diff > 1) {
        return langCode == 'en' ? "In $diff days" : (langCode == 'pt' ? "Faltam $diff dias" : "Faltan $diff días");
      } else if (diff == -1) {
        return langCode == 'en' ? "Drew yesterday" : (langCode == 'pt' ? "Sorteado ontem" : "Sorteó ayer");
      } else {
        final dias = diff.abs();
        return langCode == 'en' ? "Drew $dias days ago" : (langCode == 'pt' ? "Sorteado há $dias dias" : "Sorteó hace $dias días");
      }
    } catch (_) {
      return "";
    }
  }

  String _getPaisNombre(dynamic id) {
    if (_paises.isEmpty) return "Cargando...";
    final p = _paises.firstWhere(
      (p) => p["id"].toString() == id.toString(), 
      orElse: () => {"nombre": "Internacional"}
    );
    return p["nombre"];
  }

  Widget _buildFooterButton(AppLocalizations? l10n) {
    if (_isShowingAll || _searchController.text.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          setState(() => _isShowingAll = true);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: AppColors.yellow,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          l10n?.verTodasLoteriasMundo ?? "Ver todas las loterías del mundo",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _resolveScreen(dynamic loteria) {
    if (loteria is Map<String, dynamic>) {
      return LoteriaScreen(
        loteriaNombre: loteria["nombre"] ?? "Baloto",
        loteriaRoute: loteria["route"]?.toString(),
        loteriaData: loteria,
      );
    }
    return LoteriaScreen(loteriaNombre: loteria?.toString() ?? "Baloto");
  }
}
