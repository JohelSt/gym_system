import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger_service.dart';

class AppErrorHandler {
  static Future<void> handle(
    dynamic error,
    StackTrace stack, {
    required String context,
    BuildContext? uiContext,
    String fallbackMessage = 'Ocurrio un error inesperado.',
    bool showSnackBar = true,
  }) async {
    await LoggerService.logError(error, stack, contexto: context);

    if (!showSnackBar || uiContext == null || !uiContext.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(uiContext);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(userMessage(error, fallbackMessage: fallbackMessage)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  static String userMessage(
    dynamic error, {
    String fallbackMessage = 'Ocurrio un error inesperado.',
  }) {
    if (error is AuthException) {
      return error.message;
    }

    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'No tienes permisos para realizar esta accion.';
      }
      if (error.message.isNotEmpty) {
        return error.message;
      }
    }

    if (error is StorageException && error.message.isNotEmpty) {
      return error.message;
    }

    if (error is FormatException) {
      return 'Hay datos con formato invalido. Revisa la informacion ingresada.';
    }

    return fallbackMessage;
  }
}
