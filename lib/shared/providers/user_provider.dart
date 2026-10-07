import 'package:flutter/foundation.dart';
import '../../features/auth/data/models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  int _dataRevision = 0;
  int _resetRevision = 0;

  UserModel? get user => _user;
  int get dataRevision => _dataRevision;
  int get resetRevision => _resetRevision;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  void notifyDataChanged() {
    _dataRevision++;
    notifyListeners();
  }

  void notifyDataReset() {
    _dataRevision++;
    _resetRevision++;
    notifyListeners();
  }

  bool get isLoggedIn => _user != null;
}
