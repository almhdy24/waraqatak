/// Represents an application user for local multi-user access control.
class AppUser {
  final String id;
  final String workspaceId;
  final String username;
  final String displayName;
  final String roleId;
  final String? passwordHash;
  final String? passwordSalt;
  final String? pinHash;
  final String? pinSalt;
  final int kdfIterations;
  final int kdfVersion;
  final bool isOwner;
  final bool isActive;
  final bool setupComplete;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  const AppUser({
    required this.id,
    required this.workspaceId,
    required this.username,
    required this.displayName,
    required this.roleId,
    this.passwordHash,
    this.passwordSalt,
    this.pinHash,
    this.pinSalt,
    this.kdfIterations = 100000,
    this.kdfVersion = 1,
    this.isOwner = false,
    this.isActive = true,
    this.setupComplete = false,
    this.failedAttempts = 0,
    this.lockedUntil,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  bool get hasPassword => passwordHash != null && passwordHash!.isNotEmpty;
  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      roleId: map['role_id'] as String,
      passwordHash: map['password_hash'] as String?,
      passwordSalt: map['password_salt'] as String?,
      pinHash: map['pin_hash'] as String?,
      pinSalt: map['pin_salt'] as String?,
      kdfIterations: (map['kdf_iterations'] as num?)?.toInt() ?? 100000,
      kdfVersion: (map['kdf_version'] as num?)?.toInt() ?? 1,
      isOwner: (map['is_owner'] as num?) == 1,
      isActive: (map['is_active'] as num?) == 1,
      setupComplete: (map['setup_complete'] as num?) == 1,
      failedAttempts: (map['failed_attempts'] as num?)?.toInt() ?? 0,
      lockedUntil: map['locked_until'] != null
          ? DateTime.tryParse(map['locked_until'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.tryParse(map['last_login_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'username': username,
      'display_name': displayName,
      'role_id': roleId,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'pin_hash': pinHash,
      'pin_salt': pinSalt,
      'kdf_iterations': kdfIterations,
      'kdf_version': kdfVersion,
      'is_owner': isOwner ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'setup_complete': setupComplete ? 1 : 0,
      'failed_attempts': failedAttempts,
      'locked_until': lockedUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? workspaceId,
    String? username,
    String? displayName,
    String? roleId,
    String? passwordHash,
    String? passwordSalt,
    String? pinHash,
    String? pinSalt,
    int? kdfIterations,
    int? kdfVersion,
    bool? isOwner,
    bool? isActive,
    bool? setupComplete,
    int? failedAttempts,
    DateTime? lockedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      roleId: roleId ?? this.roleId,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      kdfIterations: kdfIterations ?? this.kdfIterations,
      kdfVersion: kdfVersion ?? this.kdfVersion,
      isOwner: isOwner ?? this.isOwner,
      isActive: isActive ?? this.isActive,
      setupComplete: setupComplete ?? this.setupComplete,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
