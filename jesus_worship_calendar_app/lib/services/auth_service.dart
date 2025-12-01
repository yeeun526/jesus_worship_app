import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 현재 로그인된 사용자
  User? get currentUser => _auth.currentUser;

  Future<User?> signIn(String email, String pw) => _auth
      .signInWithEmailAndPassword(email: email, password: pw)
      .then((c) => c.user);

  Future<User?> signUp(String email, String pw) => _auth
      .createUserWithEmailAndPassword(email: email, password: pw)
      .then((c) => c.user);

  Future<void> signOut() => _auth.signOut();
}
