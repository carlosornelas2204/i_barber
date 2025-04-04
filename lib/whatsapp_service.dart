import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

class WhatsAppService {
  static Future<bool> sendWhatsAppNotification({
    required BuildContext context,
    required String phoneNumber,
    required String message,
  }) async {
    // Formata o número de telefone (remove caracteres não numéricos e adiciona código do país)
    String formattedPhone = _formatPhoneNumber(phoneNumber);

    // Cria a URL do WhatsApp
    String url = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );

        // Mostra feedback visual para o usuário
        _showToast('WhatsApp aberto para envio da notificação');
        return true;
      } else {
        _showToast('Não foi possível abrir o WhatsApp');
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao abrir WhatsApp: $e');
      _showToast('Erro ao tentar enviar mensagem');
      return false;
    }
  }

  static String _formatPhoneNumber(String phoneNumber) {
    // Remove tudo que não é dígito
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se já tem código do país (Brasil +55)
    if (!digitsOnly.startsWith('55')) {
      digitsOnly = '55$digitsOnly';
    }

    return digitsOnly;
  }

  static void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
    );
  }
}