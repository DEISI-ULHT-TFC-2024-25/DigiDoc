import 'package:flutter/material.dart';
import '../constants/color_app.dart';
import '../models/DataBaseHelper.dart';

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

  @override
  void initState() {
    super.initState();
    _checkUserData();
  }

  Future<void> _checkUserData() async {
    final userData = await DataBaseHelper.instance.query('User_data');
    if (userData.isNotEmpty) {
      setState(() {
        _isPinSet = userData.first['pin_hash'] != null;
        _currentEmail = userData.first['email'] as String?;
        _useBiometric = userData.first['biometric_enabled'] == 1;
      });
    }
  }

  void _showPinDialog() {
    bool isChangingPin = _isPinSet;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isChangingPin ? 'Mudar PIN de Acesso' : 'Criar PIN de Acesso'),
          content: SingleChildScrollView(
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
                      if (value == null || value.isEmpty) return 'Insira o PIN atual';
                      return null;
                    },
                  ),
                TextFormField(
                  controller: _pinController,
                  decoration: const InputDecoration(labelText: 'Novo PIN'),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Insira o novo PIN';
                    if (value.length < 4) return 'PIN deve ter pelo menos 4 dígitos';
                    return null;
                  },
                ),
                if (!isChangingPin)
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Insira um email';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                CheckboxListTile(
                  title: const Text('Usar Biometria'),
                  value: _useBiometric,
                  onChanged: (value) {
                    setState(() {
                      _useBiometric = value!;
                    });
                  },
                ),
              ],
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
              onPressed: () async {
                if (isChangingPin) {
                  bool isValidPin = await DataBaseHelper.instance.validatePin(
                    _currentEmail!,
                    _confirmPinController.text,
                  );
                  if (!isValidPin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN atual inválido')),
                    );
                    return;
                  }
                }
                if (_pinController.text.isEmpty || (!isChangingPin && _emailController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preencha todos os campos obrigatórios')),
                  );
                  return;
                }
                try {
                  if (isChangingPin) {
                    await DataBaseHelper.instance.update(
                      'User_data',
                      {
                        'pin_hash': DataBaseHelper.instance.hashPin(_pinController.text),
                        'biometric_enabled': _useBiometric ? 1 : 0,
                      },
                      where: 'email = ?',
                      whereArgs: [_currentEmail],
                    );
                  } else {
                    await DataBaseHelper.instance.registerUser(
                      _emailController.text,
                      _pinController.text,
                      _useBiometric,
                    );
                  }
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isChangingPin ? 'PIN alterado com sucesso' : 'PIN criado com sucesso')),
                  );
                  setState(() {
                    _isPinSet = true;
                    _currentEmail = isChangingPin ? _currentEmail : _emailController.text;
                  });
                  _pinController.clear();
                  _confirmPinController.clear();
                  _emailController.clear();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar: $e')),
                  );
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

  void _showChangeEmailDialog() {
    final newEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mudar Email'),
          content: TextFormField(
            controller: newEmailController,
            decoration: const InputDecoration(labelText: 'Novo Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Insira um email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Email inválido';
              }
              return null;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newEmailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insira um email válido')),
                  );
                  return;
                }
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao alterar email: $e')),
                  );
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
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _emailController.dispose();
    super.dispose();
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
              title: Text(_isPinSet ? 'Mudar PIN de Acesso' : 'Criar PIN de Acesso'),
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
}