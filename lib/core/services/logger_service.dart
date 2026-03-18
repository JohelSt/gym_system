import 'package:supabase_flutter/supabase_flutter.dart';

class LoggerService {
  static final _supabase = Supabase.instance.client;

  // LOG DE EVENTOS DE NEGOCIO
  static Future<void> logEvento({
    required String tipo,
    required String detalle,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from('logs_sistema').insert({
        'tipo_evento': tipo,
        'detalle': detalle,
        'usuario_ejecutor': user?.email ?? 'Sistema/Anónimo',
        'metadata': metadata,
      });
    } catch (e) {
      print("Error crítico: No se pudo guardar el log localmente: $e");
    }
  }

  // LOG DE ERRORES (EXCEPCIONES)
  static Future<void> logError(dynamic e, StackTrace? stack, {String? contexto}) async {
    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from('logs_errores').insert({
        'error_mensaje': e.toString(),
        'stack_trace': stack?.toString(),
        'contexto': contexto ?? 'Desconocido',
        'usuario_id': user?.id,
      });
    } catch (err) {
      print("Error al intentar loguear una excepción: $err");
    }
  }
}