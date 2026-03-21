import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

class CampanasService {
  CampanasService._();

  static final _supabase = Supabase.instance.client;
  static final Set<int> _campaignsShownInSession = <int>{};

  static Future<List<Map<String, dynamic>>> obtenerCampanasActivas() async {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = await _supabase
        .from('campanas')
        .select()
        .eq('activa', true)
        .lte('fecha_inicio', hoy)
        .gte('fecha_fin', hoy)
        .order('fecha_inicio', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> obtenerCampanaPrincipal() async {
    final campanas = await obtenerCampanasActivas();
    if (campanas.isEmpty) {
      return null;
    }
    return campanas.first;
  }

  static Future<void> mostrarBannerSiAplica(BuildContext context) async {
    final campana = await obtenerCampanaPrincipal();
    if (campana == null || !context.mounted) {
      return;
    }

    final campaignId = campana['id'] is int
        ? campana['id'] as int
        : int.tryParse(campana['id']?.toString() ?? '');

    if (campaignId == null || _campaignsShownInSession.contains(campaignId)) {
      return;
    }

    _campaignsShownInSession.add(campaignId);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CampanaBannerDialog(campana: campana),
    );
  }
}

class _CampanaBannerDialog extends StatelessWidget {
  const _CampanaBannerDialog({required this.campana});

  final Map<String, dynamic> campana;

  @override
  Widget build(BuildContext context) {
    final imageUrl = campana['imagen_url']?.toString().trim();
    final fechaInicio = DateTime.tryParse(campana['fecha_inicio']?.toString() ?? '');
    final fechaFin = DateTime.tryParse(campana['fecha_fin']?.toString() ?? '');
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: GymTheme.darkGray,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildImageFallback(),
                          )
                        : _buildImageFallback(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: GymTheme.neonGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'CAMPAÑA ACTIVA',
                            style: TextStyle(
                              color: GymTheme.neonGreen,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          campana['titulo']?.toString() ?? 'Campaña',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          campana['descripcion']?.toString() ?? 'Sin descripcion.',
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        if (fechaInicio != null || fechaFin != null)
                          Text(
                            'Vigencia: ${_formatDate(fechaInicio)} - ${_formatDate(fechaFin)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('ENTENDIDO'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildImageFallback() {
    return Container(
      height: 220,
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.campaign_outlined,
          color: GymTheme.neonGreen,
          size: 64,
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }
    return DateFormat('dd/MM/yyyy').format(value);
  }
}
