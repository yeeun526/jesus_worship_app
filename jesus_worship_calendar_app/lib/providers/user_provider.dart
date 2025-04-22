// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  String? uid, role;
  final AuthService _authService = AuthService();
  final FirestoreService _fs = FirestoreService();

  Future<void> loadCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      uid = user.uid;
      role = await _fs.fetchUserRole(uid!);
    }
    notifyListeners();
  }
}
