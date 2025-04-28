class UserModel {
  final String uid;
  final String email;
  final String role;
  final String? name;
  UserModel(
      {required this.uid, required this.email, required this.role, this.name});
}
