import 'package:flutter/foundation.dart';

class CurrentStateProcessing extends ChangeNotifier {
  bool _isProcessing = false;
  bool _isCorrecting = false;
  bool _internalProcessing = false;

  bool get isProcessing => _isProcessing;
  bool get isCorrecting => _isCorrecting;
  bool get internalProcessing => _internalProcessing;

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void setCorrecting(bool value) {
    _isCorrecting = value;
    notifyListeners();
  }

  void setInternalProcessing(bool value) {
    _internalProcessing = value;
    notifyListeners();
  }
}