import 'package:flutter/material.dart';
import 'dart:math';
import '../constants/color_app.dart';
import '../models/DataBaseHelper.dart';
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
    final smtpServer = gmail('digidoc.mail.service@gmail.com', '@Digi7doc2001!');
    final message = Message()
      ..from = const Address('digidoc.mail.service@gmail.com', 'DigiDoc')
      ..recipients.add(_email!)
      ..subject = 'Código de Verificação do DigiDoc'
      ..text = 'Seu código de verificação é: $_generatedCode';

    try {
      await send(message, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de verificação enviado para o email')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar email: $e')),
      );
    }
  }

  void _verifyCode() {
    if (_codeController.text == _generatedCode) {
      Navigator.pushReplacementNamed(context, '/security');
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
          ],
        ),
      ),
    );
  }
}