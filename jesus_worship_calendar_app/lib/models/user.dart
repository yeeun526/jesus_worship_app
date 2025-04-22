class UserModel {
  final String uid;
  final String email;
  final String role;
  final String? name;
  UserModel(
      {required this.uid, required this.email, required this.role, this.name});
  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
      uid: m['uid'],
      email: m['email'],
      role: m['role'],
      name: m['name'] as String?);
}
