import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:provider/provider.dart';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import '../services/current_state_processing.dart';

class CreateNewPinScreen extends StatefulWidget {
  const CreateNewPinScreen({super.key});

  @override
  _CreateNewPinScreenState createState() => _CreateNewPinScreenState();
}

class _CreateNewPinScreenState extends State<CreateNewPinScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final newEmailController = TextEditingController();
  final codeController = TextEditingController();

  String? generatedCode;
  bool _useBiometric = false;
  bool _validationCodeSent = false;
  bool _isPinSet = false;
  String? _currentEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUserData();
  }

  Future<void> _checkUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userData = await DataBaseHelper.instance.query('User_data');
      print('CreateNewPinScreen: Dados do usuário carregados: $userData');
      if (userData.isNotEmpty) {
        setState(() {
          _isPinSet = userData.first['pin_hash'] != null;
          _currentEmail = userData.first['email'] as String?;
          _useBiometric = userData.first['biometric_enabled'] == 1;
        });
        print('CreateNewPinScreen: _isPinSet: $_isPinSet, _currentEmail: $_currentEmail');
      } else {
        print('CreateNewPinScreen: Nenhum usuário encontrado em User_data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum usuário encontrado na base de dados')),
          );
        }
      }
    } catch (e) {
      print('CreateNewPinScreen: Erro ao carregar dados do usuário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados do usuário: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPinDialog() {
    bool localUseBiometric = _useBiometric;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCardBackground
                  : AppColors.cardBackground,
              title: Text(
                'Criar Novo PIN de Acesso',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _pinController,
                        decoration: InputDecoration(
                          labelText: 'Novo PIN',
                          labelStyle: GoogleFonts.poppins(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkCardBackground.withOpacity(0.8)
                              : AppColors.cardBackground,
                        ),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira o novo PIN';
                          }
                          if (value.length < 4) {
                            return 'O PIN deve ter pelo menos 4 dígitos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPinController,
                        decoration: InputDecoration(
                          labelText: 'Confirmar Novo PIN',
                          labelStyle: GoogleFonts.poppins(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkCardBackground.withOpacity(0.8)
                              : AppColors.cardBackground,
                        ),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira o novo PIN';
                          }
                          if (value.length < 4) {
                            return 'O PIN deve ter pelo menos 4 dígitos';
                          }
                          return null;
                        },
                      ),
                      CheckboxListTile(
                        title: Text(
                          'Usar Biometria',
                          style: GoogleFonts.poppins(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        value: localUseBiometric,
                        activeColor: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkPrimaryGradientStart
                            : AppColors.darkerBlue,
                        onChanged: (value) {
                          setDialogState(() {
                            localUseBiometric = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _pinController.clear();
                    _confirmPinController.clear();
                    newEmailController.clear();
                  },
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkPrimaryGradientStart
                          : AppColors.darkerBlue,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      bool pinMatched = _confirmPinController.text == _pinController.text;
                      if (!pinMatched) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Os PINs não se correspondem')),
                          );
                        }
                        setState(() {
                          _isLoading = false;
                        });
                        return;
                      } else {
                        await DataBaseHelper.instance.update(
                          'User_data',
                          {
                            'pin_hash': DataBaseHelper.instance.hashPin(_pinController.text),
                            'biometric_enabled': localUseBiometric ? 1 : 0,
                          },
                          where: 'email = ?',
                          whereArgs: [_currentEmail],
                        );
                      }

                      setState(() {
                        _useBiometric = localUseBiometric;
                        _isPinSet = true;
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN criado com sucesso')),
                        );
                        Navigator.pop(dialogContext);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                              (route) => false,
                        );
                      }
                    } catch (e) {
                      print('CreateNewPinScreen: Erro ao salvar: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao salvar: $e')),
                        );
                      }
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                      _pinController.clear();
                      _confirmPinController.clear();
                      newEmailController.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkPrimaryGradientStart
                        : AppColors.darkerBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirmar',
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.calmWhite,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendValidationEmail(String email) async {
    print('CreateNewPinScreen: Iniciando _sendValidationEmail para $email');
    if (email.isEmpty) {
      print('CreateNewPinScreen: E-mail vazio, não enviando validação');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail não pode estar vazio')),
        );
      }
      return;
    }

    if (generatedCode == null) {
      print('CreateNewPinScreen: Código de validação não gerado');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro interno: código de validação não gerado')),
        );
      }
      return;
    }

    if (_currentEmail == null) {
      print('CreateNewPinScreen: Email atual não definido');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Email atual não definido')),
        );
      }
      return;
    }

    final smtpServer = gmail('digidoc.mail.service@gmail.com', 'gojg fzjo whnj skxj');
    final message = Message()
      ..from = const Address('digidoc.mail.service@gmail.com', 'DigiDoc')
      ..recipients.add(email)
      ..subject = 'Código de Validação do DigiDoc'
      ..html = '''
      <!DOCTYPE html>
      <html lang="pt">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Código de Validação - DigiDoc</title>
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
              <h2 style="color: #333333; font-size: 22px; margin: 0 0 15px;">Validação de E-mail</h2>
              <p style="color: #555555; font-size: 16px; line-height: 1.5; margin: 0 0 20px;">
                Olá,
              </p>
              <p style="color: #555555; font-size: 16px; line-height: 1.5; margin: 0 0 20px;">
                Você solicitou a validação do seu e-mail no aplicativo DigiDoc. Toque e segure o código abaixo para copiá-lo:
              </p>
              <div style="display: inline-block; background-color: #e6f0ff; border: 2px solid #007bff; border-radius: 8px; padding: 15px 25px; margin: 20px 0; user-select: text; -webkit-user-select: text; -moz-user-select: text; -ms-user-select: text;">
                <span style="font-size: 28px; font-weight: bold; color: #007bff; letter-spacing: 2px;">$generatedCode</span>
              </div>
              <p style="color: #555555; font-size: 16px; line-height: 1.5; margin: 0 0 20px;">
                Insira o código no aplicativo para confirmar seu e-mail. Caso não consiga copiar, anote o código e digite-o manualmente.
              </p>
              <p style="color: #777777; font-size: 14px; line-height: 1.5; margin: 20px 0 0;">
                Se você não solicitou esta validação, ignore este e-mail. Verifique também a pasta de spam ou lixo eletrônico caso não encontre este e-mail na sua caixa de entrada.
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
      print('CreateNewPinScreen: Preparando para enviar e-mail para $email com código $generatedCode');
      print('CreateNewPinScreen: Configurando SMTP com servidor: smtp.gmail.com, usuário: digidoc.mail.service@gmail.com');
      final sendReport = await send(message, smtpServer);
      print('CreateNewPinScreen: E-mail enviado com sucesso: $sendReport');
      print('CreateNewPinScreen: Salvando código $generatedCode no banco para email $_currentEmail');
      await DataBaseHelper.instance.update(
        'User_data',
        {'verification_code': generatedCode},
        where: 'email = ?',
        whereArgs: [_currentEmail],
      );
      setState(() {
        _validationCodeSent = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código de verificação enviado para o e-mail')),
        );
      }
    } catch (e, stackTrace) {
      print('CreateNewPinScreen: Erro detalhado ao enviar e-mail: $e');
      print('CreateNewPinScreen: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar e-mail: $e')),
        );
      }
    }
  }

  Future<void> _validateEmail() async {
    print('CreateNewPinScreen: Iniciando _validateEmail');
    final email = newEmailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      print('CreateNewPinScreen: E-mail inválido: $email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insira um e-mail válido')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      generatedCode = (Random().nextInt(900000) + 100000).toString();
    });

    await _sendValidationEmail(email);

    setState(() {
      _isLoading = false;
    });
  }

  Future<bool> _verifyCode(String code) async {
    try {
      print('CreateNewPinScreen: Verificando código $code para email $_currentEmail');
      final userData = await DataBaseHelper.instance.query(
        'User_data',
        where: 'email = ? AND verification_code = ?',
        whereArgs: [_currentEmail, code],
      );
      print('CreateNewPinScreen: Resultado da consulta: $userData');
      return userData.isNotEmpty;
    } catch (e) {
      print('CreateNewPinScreen: Erro ao verificar código: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao verificar código: $e')),
        );
      }
      return false;
    }
  }

  void _showChangeEmailDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCardBackground
                  : AppColors.cardBackground,
              title: Text(
                'Mudar Email',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: newEmailController,
                        decoration: InputDecoration(
                          labelText: 'Novo Email',
                          labelStyle: GoogleFonts.poppins(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkCardBackground.withOpacity(0.8)
                              : AppColors.cardBackground,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira um email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Insira um email válido';
                          }
                          return null;
                        },
                      ),
                      if (_validationCodeSent) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: codeController,
                          decoration: InputDecoration(
                            labelText: 'Código de Validação',
                            labelStyle: GoogleFonts.poppins(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkCardBackground.withOpacity(0.8)
                                : AppColors.cardBackground,
                          ),
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Insira o código de validação';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _validationCodeSent = false;
                      generatedCode = null;
                      newEmailController.clear();
                      codeController.clear();
                    });
                  },
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkPrimaryGradientStart
                          : AppColors.darkerBlue,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      if (!_validationCodeSent) {
                        await _validateEmail();
                        setDialogState(() {}); // Update dialog to show code field
                      } else {
                        final code = codeController.text.trim();
                        final isValidCode = await _verifyCode(code);
                        if (!isValidCode) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código de validação incorreto')),
                            );
                          }
                          setState(() {
                            _isLoading = false;
                          });
                          return;
                        }

                        print('CreateNewPinScreen: Atualizando email para ${newEmailController.text}');
                        await DataBaseHelper.instance.update(
                          'User_data',
                          {
                            'email': newEmailController.text,
                            'verification_code': null,
                          },
                          where: 'email = ?',
                          whereArgs: [_currentEmail],
                        );
                        setState(() {
                          _currentEmail = newEmailController.text;
                          _validationCodeSent = false;
                          generatedCode = null;
                          newEmailController.clear();
                          codeController.clear();
                        });
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email alterado com sucesso')),
                          );
                        }
                      }
                    } catch (e) {
                      print('CreateNewPinScreen: Erro ao processar: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao processar: $e')),
                        );
                      }
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkPrimaryGradientStart
                        : AppColors.darkerBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _validationCodeSent ? 'Confirmar Código' : 'Confirmar',
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.calmWhite,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<CurrentStateProcessing>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Segurança',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.calmWhite,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkPrimaryGradientStart.withAlpha(250)
            : AppColors.darkerBlue,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextPrimary
              : AppColors.calmWhite,
        ),
      ),
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? null
            : AppColors.background,
        child: _isLoading
            ? Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkPrimaryGradientStart
                : AppColors.darkerBlue,
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 2,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCardBackground
                    : AppColors.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  title: Text(
                    'Criar Novo PIN',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkPrimaryGradientStart
                        : AppColors.darkerBlue,
                  ),
                  onTap: _showPinDialog,
                ),
              ),
              const SizedBox(height: 8),
              if (_currentEmail != null)
                Card(
                  elevation: 2,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    title: Text(
                      'Mudar Email',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _currentEmail!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkPrimaryGradientStart
                          : AppColors.darkerBlue,
                    ),
                    onTap: _showChangeEmailDialog,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    newEmailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('generatedCode', generatedCode));
  }
}