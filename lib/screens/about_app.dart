import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/color_app.dart';
import 'package:google_fonts/google_fonts.dart';
import 'policy_privacy.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'digidoc.mail.service@gmail.com',
      query: 'subject=Suporte DigiDoc',
    );
    if (await canLaunchUrl(emailUri)) await launchUrl(emailUri);
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUri = Uri.parse('https://wa.me/913181864?text=Olá, preciso de suporte com o DigiDoc');
    if (await canLaunchUrl(whatsappUri)) await launchUrl(whatsappUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkerBlue, Colors.blue[900]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Sobre a Aplicação',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBackground
                        : AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 4,
                          color: AppColors.darkBackground.withAlpha(200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  'Versão Atual: 1.0.1',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.calmWhite),
                                ),
                                const SizedBox(height: 20),
                                ListTile(
                                  leading: const Icon(Icons.lock, color: AppColors.calmWhite),
                                  title: Text('Política de Privacidade', style: GoogleFonts.poppins(fontSize: 16, color: AppColors.calmWhite)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const PolicyPrivacyScreen()),
                                    );
                                  },
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.email, color: AppColors.calmWhite),
                                  title: Text('Contactar Suporte', style: GoogleFonts.poppins(fontSize: 16, color: AppColors.calmWhite)),
                                  subtitle: Text('Via Email ou WhatsApp', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                      builder: (context) => Container(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.email, color: AppColors.darkerBlue),
                                              title: Text('Email', style: GoogleFonts.poppins(fontSize: 16)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _launchEmail();
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.phone, color: AppColors.darkerBlue),
                                              title: Text('WhatsApp', style: GoogleFonts.poppins(fontSize: 16)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _launchWhatsApp();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Notas de Atualização',
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.calmWhite
                              : AppColors.darkerBlue,),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.calmWhite.withAlpha(150),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '- Nova interface de usuário\n'
                                '- Suporte para autenticação com PIN\n'
                                '- Melhorias na captura de documentos\n'
                                '- Correções de bugs e melhorias de desempenho',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}