import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/color_app.dart';
import 'package:google_fonts/google_fonts.dart';

class PolicyPrivacyScreen extends StatelessWidget {
  const PolicyPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextPrimary
              : Colors.white,
        ),
        title: Text(
          'Política de Privacidade',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkPrimaryGradientStart.withAlpha(250)
            : AppColors.darkerBlue,
      ),
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Última atualização: 26.06.25',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'A tua privacidade é importante para nós. Esta Política de Privacidade descreve como a aplicação DigiDoc recolhe, utiliza e protege os teus dados pessoais, em conformidade com o Regulamento Geral sobre a Proteção de Dados (RGPD - UE 2016/679).',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Dados Recolhidos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '- Fotografias de documentos pessoais\n'
                    '- Texto extraído automaticamente dos documentos\n'
                    '- Datas de validade dos documentos\n'
                    '- Dados definidos pelo utilizador (ex.: nome de dossiês, alertas personalizados)\n'
                    '- Dados técnicos do dispositivo (limitados ao necessário para funcionamento)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Finalidade do Tratamento',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '- Armazenar e organizar documentos de forma segura\n'
                    '- Permitir a pesquisa e consulta rápida dos documentos\n'
                    '- Gerar alertas e notificações relacionados com a validade dos documentos\n'
                    '- Melhorar a experiência do utilizador na aplicação',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Base Legal',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '- Consentimento explícito, ao utilizares a aplicação e carregares documentos\n'
                    '- Execução de contrato, quando utilizas funcionalidades essenciais da aplicação\n'
                    '- Interesse legítimo, no caso de melhoria contínua e segurança da app',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Partilha de Dados',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A DigiDoc não partilha os teus dados pessoais com terceiros. Todos os dados ficam armazenados localmente no teu dispositivo, a menos que optes por backup ou sincronização com plataformas externas (futuramente).',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Retenção dos Dados',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Os dados são guardados enquanto permanecerem na aplicação. Podes eliminá-los a qualquer momento através da própria interface da DigiDoc.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Segurança',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '- Proteção por código de acesso\n'
                    '- Armazenamento local encriptado (quando possível)\n'
                    '- Limitação de acesso aos dados apenas ao utilizador',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Os teus direitos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '- Aceder aos teus dados\n'
                    '- Corrigir ou apagar dados\n'
                    '- Retirar o consentimento\n'
                    '- Solicitar a portabilidade\n'
                    '- Apresentar reclamação à CNPD (www.cnpd.pt)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Contacto',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.darkerBlue,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final Uri emailUri = Uri(
                    scheme: 'mailto',
                    path: 'digidoc.mail.service@gmail.com',
                  );
                  if (await canLaunchUrl(emailUri)) await launchUrl(emailUri);
                },
                child: Text(
                  'Se tiveres alguma dúvida sobre esta Política de Privacidade ou sobre os teus dados, contacta-nos: 📧 digidoc.mail.service@gmail.com',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : Colors.black87,
                    decoration: TextDecoration.underline,
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