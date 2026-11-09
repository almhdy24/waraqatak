/// Represents a user role (e.g., Owner, Manager, Accountant, Salesperson, Inventory Manager).
class Role {
  final String id;
  final String workspaceId;
  final String name;
  final String? description;
  final bool isSystem;
  final bool isTemplate;

  const Role({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.description,
    this.isSystem = false,
    this.isTemplate = false,
  });

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      isSystem: (map['is_system'] as num?) == 1,
      isTemplate: (map['is_template'] as num?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'name': name,
      'description': description,
      'is_system': isSystem ? 1 : 0,
      'is_template': isTemplate ? 1 : 0,
    };
  }

  Role copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? description,
    bool? isSystem,
    bool? isTemplate,
  }) {
    return Role(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      description: description ?? this.description,
      isSystem: isSystem ?? this.isSystem,
      isTemplate: isTemplate ?? this.isTemplate,
    );
  }
}
