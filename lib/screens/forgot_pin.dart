import 'package:flutter/material.dart';
import 'dart:math';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  _ForgotPinScreenState createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _codeController = TextEditingController();
  String? _email;
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndSendCode();
  }

  Future<void> _loadUserDataAndSendCode() async {
    final userData = await DataBaseHelper.instance.query('User_data');
    if (userData.isNotEmpty) {
      setState(() {
        _email = userData.first['email'] as String?;
      });
      if (_email != null) {
        _generatedCode = (Random().nextInt(900000) + 100000).toString();
        await _sendVerificationEmail();
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    final smtpServer = gmail('digidoc.mail.service@gmail.com', 'gojg fzjo whnj skxj');
    final message = Message()
      ..from = const Address('digidoc.mail.service@gmail.com', 'DigiDoc')
      ..recipients.add(_email!)
      ..subject = 'Código de Verificação do DigiDoc'
      ..html = '''
      <!DOCTYPE html>
      <html lang="pt">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Código de Verificação - DigiDoc</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: 'Helvetica Neue', Arial, sans-serif; color: #333333; background-color: #f4f4f4;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Cabeçalho -->
          <tr>
            <td style="background: linear-gradient(135deg, #007bff, #005b9f); padding: 20px; text-align: center; border-top-left-radius: 8px; border-top-right-radius: 8px;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">DigiDoc</h1>
              <p style="color: #e6f0ff; margin: 5px 0 0; font-size: 14px;">Gerenciamento Seguro de Documentos</p>
            </td>
          </tr>
          <!-- Corpo -->
          <tr>
            <td style="padding: 30px 20px; text-align: center;">
              <h2 style="color: #333333; font-size: 22px; margin: 0 0 15px;">Código de Verificação</h2>
              <p style="color: #555555; font-size: 16px; line-height: 1.5; margin: 0 0 20px;">
                Olá,
              </p>
              <p style="color: #555555; font-size: 16px; line-height: 1.5; margin: 0 0 20px;">
                Você solicitou a verificação do seu e-mail no aplicativo DigiDoc. Toque e segure o código abaixo para copiá-lo:
              </p>
              <div style="display: inline-block; background-color: #e6f0ff; border: 2px solid #007bff; border-radius: 8px; padding: 15px 25px; margin: 20px 0; user-select: text; -webkit-user-select: text; -moz-user-select: text; -ms-user-select: text;">
                <span style="font-size: 28px; font-weight: bold; color: #007bff; letter-spacing: 2px;">$_generatedCode</span>
              </div>
              <p style="color: #555555; font-size: 16px; line-height: 1.5; margin: 0 0 20px;">
                Insira o código no aplicativo para concluir a verificação.
              </p>
              <p style="color: #777777; font-size: 14px; line-height: 1.5; margin: 20px 0 0;">
                Se você não solicitou este código, ignore este e-mail. Verifique também a pasta de spam ou lixo eletrônico caso não encontre este e-mail na sua caixa de entrada.
              </p>
            </td>
          </tr>
          <!-- Rodapé -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 15px 20px; text-align: center; border-bottom-left-radius: 8px; border-bottom-right-radius: 8px;">
              <p style="color: #777777; font-size: 12px; margin: 0; line-height: 1.4;">
                Atenciosamente,<br>
                <strong>Equipa DigiDoc</strong><br>
                <a href="mailto:digidoc.mail.service@gmail.com" style="color: #007bff; text-decoration: none;">digidoc.mail.service@gmail.com</a>
              </p>
              <p style="color: #777777; font-size: 12px; margin: 10px 0 0;">
                © 2025 DigiDoc. Todos os direitos reservados.
              </p>
            </td>
          </tr>
        </table>
      </body>
      </html>
    ''';

    try {
      print('Enviando e-mail de verificação para ${_email!} com código $_generatedCode');
      final sendReport = await send(message, smtpServer);
      print('E-mail enviado com sucesso: $sendReport');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de verificação enviado para o email')),
      );
    } catch (e) {
      print('Erro ao enviar e-mail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar e-mail: $e')),
      );
    }
  }

  void _verifyCode() {
    if (_codeController.text == _generatedCode) {
      Navigator.pushReplacementNamed(context, '/create_new_pin');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código verificado! Você pode criar um novo PIN.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código inválido')),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar PIN', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Um código de verificação foi enviado para $_email',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Código de Verificação',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkerBlue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUserDataAndSendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkerBlue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('Reenviar Email', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}