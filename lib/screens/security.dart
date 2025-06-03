import 'package:flutter/material.dart';
import '../constants/color_app.dart';
import '../models/data_base_helper.dart';
import 'auth.dart';

class SecurityScreen extends StatefulWidget {

  const SecurityScreen({super.key});

  @override
  _SecurityScreenState createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _emailController = TextEditingController();
  bool _useBiometric = false;
  bool _isPinSet = false;
  String? _currentEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUserData();
  }

  Future<void> _checkUserData() async {
    try {
      final userData = await DataBaseHelper.instance.query('User_data');
      print('SecurityScreen: Dados do usuário carregados: $userData');
      if (userData.isNotEmpty) {
        setState(() {
          _isPinSet = userData.first['pin_hash'] != null;
          _currentEmail = userData.first['email'] as String?;
          _useBiometric = userData.first['biometric_enabled'] == 1;
        });
        print('SecurityScreen: _isPinSet: $_isPinSet, _currentEmail: $_currentEmail');
      } else {
        print('SecurityScreen: Nenhum usuário encontrado em User_data');
      }
    } catch (e) {
      print('SecurityScreen: Erro ao carregar dados do usuário: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showPinDialog() {
    bool isChangingPin = _isPinSet;
    bool localUseBiometric = _useBiometric;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isChangingPin
                  ? 'Mudar PIN de Acesso'
                  : 'Criar PIN de Acesso'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isChangingPin)
                        TextFormField(
                          controller: _confirmPinController,
                          decoration: const InputDecoration(labelText: 'PIN Atual'),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Insira o PIN atual';
                            }
                            return null;
                          },
                        ),
                      TextFormField(
                        controller: _pinController,
                        decoration: const InputDecoration(labelText: 'Novo PIN'),
                        obscureText: true,
                        keyboardType: TextInputType.number,
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
                      if (!isChangingPin)
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
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
                      CheckboxListTile(
                        title: const Text('Usar Biometria'),
                        value: localUseBiometric,
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
                    _emailController.clear();
                  },
                  child: const Text('Cancelar'),
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
                      if (isChangingPin) {
                        bool isValidPin = await DataBaseHelper.instance.validatePin(
                          _currentEmail!,
                          _confirmPinController.text,
                        );
                        if (!isValidPin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN atual inválido')),
                          );
                          setState(() {
                            _isLoading = false;
                          });
                          return;
                        }
                        await DataBaseHelper.instance.update(
                          'User_data',
                          {
                            'pin_hash': DataBaseHelper.instance.hashPin(_pinController.text),
                            'biometric_enabled': localUseBiometric ? 1 : 0,
                          },
                          where: 'email = ?',
                          whereArgs: [_currentEmail],
                        );
                      } else {
                        await DataBaseHelper.instance.registerUser(
                          _emailController.text,
                          _pinController.text,
                          localUseBiometric,
                        );
                      }

                      setState(() {
                        _useBiometric = localUseBiometric;
                        _isPinSet = true;
                        if (!isChangingPin) {
                          _currentEmail = _emailController.text;
                        }
                      });

                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isChangingPin
                              ? 'PIN alterado com sucesso'
                              : 'PIN criado com sucesso'),
                        ),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                      );

                    } catch (e) {
                      print('SecurityScreen: Erro ao salvar: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao salvar: $e')),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                      _pinController.clear();
                      _confirmPinController.clear();
                      _emailController.clear();
                    }
                  },
                  child: const Text('Confirmar'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkerBlue),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeEmailDialog() {
    final newEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Mudar Email'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: newEmailController,
              decoration: const InputDecoration(labelText: 'Novo Email'),
              keyboardType: TextInputType.emailAddress,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
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
                  await DataBaseHelper.instance.update(
                    'User_data',
                    {'email': newEmailController.text},
                    where: 'email = ?',
                    whereArgs: [_currentEmail],
                  );
                  setState(() {
                    _currentEmail = newEmailController.text;
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email alterado com sucesso')),
                  );
                } catch (e) {
                  print('SecurityScreen: Erro ao alterar email: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao alterar email: $e')),
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              child: const Text('Confirmar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkerBlue),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Segurança', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: Text(_isPinSet
                  ? 'Mudar PIN de Acesso'
                  : 'Criar PIN de Acesso'),
              onTap: _showPinDialog,
            ),
            if (_currentEmail != null)
              ListTile(
                title: const Text('Mudar Email'),
                subtitle: Text(_currentEmail!),
                onTap: _showChangeEmailDialog,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}