class UserModel {
  final int? id;
  final String email;
  final String displayName;
  final String currency;
  final String? avatarUrl;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.email,
    required this.displayName,
    this.currency = 'THB',
    this.avatarUrl,
    this.lastLoginAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'currency': currency,
      'avatar_url': avatarUrl,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      currency: map['currency'] ?? 'THB',
      avatarUrl: map['avatar_url'],
      lastLoginAt: map['last_login_at'] != null 
          ? DateTime.parse(map['last_login_at']) 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }
}