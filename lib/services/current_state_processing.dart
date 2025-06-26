import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrentStateProcessing extends ChangeNotifier {
  bool _isProcessing = false;
  bool _isCorrecting = false;
  bool _internalProcessing = false;
  bool _isDarkMode = false;

  bool get isProcessing => _isProcessing;
  bool get isCorrecting => _isCorrecting;
  bool get internalProcessing => _internalProcessing;
  bool get isDarkMode => _isDarkMode;

  CurrentStateProcessing() {
    _loadTheme();
  }

  void setProcessing(bool value) {
    if (_isProcessing != value) {
      _isProcessing = value;
      notifyListeners();
    }
  }

  void setCorrecting(bool value) {
    if (_isCorrecting != value) {
      _isCorrecting = value;
      notifyListeners();
    }
  }

  void setInternalProcessing(bool value) {
    if (_internalProcessing != value) {
      _internalProcessing = value;
      notifyListeners();
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      notifyListeners();
    }
  }
}