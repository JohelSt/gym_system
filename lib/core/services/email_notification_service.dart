import 'package:supabase_flutter/supabase_flutter.dart';

class EmailNotificationService {
  static Future<void> enviarRecordatorioPagoVencido({
    required String clienteId,
  }) async {
    await Supabase.instance.client.functions.invoke(
      'send-overdue-payment-email',
      body: {'clienteId': clienteId},
    );
  }
}
