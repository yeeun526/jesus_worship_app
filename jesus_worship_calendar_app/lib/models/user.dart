class UserModel {
  final String uid;
  final String email;
  final String role;
  UserModel({required this.uid, required this.email, required this.role});
  factory UserModel.fromMap(Map<String, dynamic> m) =>
      UserModel(uid: m['uid'], email: m['email'], role: m['role']);
}
