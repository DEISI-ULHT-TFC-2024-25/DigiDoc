import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/color_app.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'digidoc.mail.service@gmail.com',
      query: 'subject=Suporte DigiDoc',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUri = Uri.parse('https://wa.me/1234567890?text=Olá, preciso de suporte com o DigiDoc');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri policyUri = Uri.parse('https://digidoc.com/privacy-policy');
    if (await canLaunchUrl(policyUri)) {
      await launchUrl(policyUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre a Aplicação', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Versão Atual: 1.0.0'),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Política de Privacidade'),
              onTap: _launchPrivacyPolicy,
            ),
            ListTile(
              title: const Text('Contactar Suporte'),
              subtitle: const Text('Via Email ou WhatsApp'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Contactar Suporte'),
                      content: const Text('Escolha uma opção para contactar o suporte:'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _launchEmail();
                          },
                          child: const Text('Email'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _launchWhatsApp();
                          },
                          child: const Text('WhatsApp'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Notas de Atualização',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '- Nova interface de usuário\n'
                  '- Suporte para autenticação com PIN\n'
                  '- Melhorias na captura de documentos\n'
                  '- Correções de bugs e melhorias de desempenho',
            ),
          ],
        ),
      ),
    );
  }
}