class Student {
  final String uid;
  final String email;
  final String? name;

  const Student({
    required this.uid,
    required this.email,
    this.name,
  });

  /// users/{uid} 문서를 Student로 변환할 때 쓰면 편해요.
  factory Student.fromFirestore(String id, Map<String, dynamic> data) {
    return Student(
      uid: id,
      email: (data['email'] as String?) ?? '',
      name: data['name'] as String?,
    );
  }

  /// 정렬/검색 등에 유용
  String get displayName => name?.trim().isNotEmpty == true ? name! : email;
}
