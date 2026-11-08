import 'package:sqflite/sqflite.dart';
import '../services/access/access_seeder.dart';
import '../services/access/audit_service.dart';

/// Data Access Object for Multi-User Access Control and Permissions.
///
/// Follows the same pattern as [ReferencePricingDao].
abstract final class AccessDao {
  static const String defaultWorkspaceId = 'default-workspace';
  static const String ownerRoleId = 'role-owner';
  static const String ownerUserId = 'user-owner';

  /// Helper to check if a column exists in a given table.
  static Future<bool> columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((c) => c['name'] == column);
  }

  /// Helper to check if a table exists.
  static Future<bool> tableExists(DatabaseExecutor db, String table) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [table],
    );
    return tables.isNotEmpty;
  }

  /// Creates access control tables for fresh installs or migrations.
  static Future<void> createAccessControlTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        is_system INTEGER NOT NULL DEFAULT 0,
        is_template INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        username TEXT UNIQUE COLLATE NOCASE NOT NULL,
        display_name TEXT NOT NULL,
        role_id TEXT NOT NULL,
        password_hash TEXT,
        password_salt TEXT,
        pin_hash TEXT,
        pin_salt TEXT,
        kdf_iterations INTEGER DEFAULT 100000,
        kdf_version INTEGER DEFAULT 1,
        is_owner INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        setup_complete INTEGER NOT NULL DEFAULT 0,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_login_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS role_permissions (
        role_id TEXT NOT NULL,
        permission_key TEXT NOT NULL,
        PRIMARY KEY (role_id, permission_key)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_permission_overrides (
        user_id TEXT NOT NULL,
        permission_key TEXT NOT NULL,
        effect TEXT NOT NULL,
        PRIMARY KEY (user_id, permission_key)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_workspace ON users(workspace_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_roles_workspace ON roles(workspace_id)',
    );
  }

  /// Adds access attribution columns to existing tables (idempotent).
  static Future<void> ensureAttributionColumns(DatabaseExecutor db) async {
    // 1. audit_log
    if (await tableExists(db, 'audit_log')) {
      if (!await columnExists(db, 'audit_log', 'user_id')) {
        await db.execute('ALTER TABLE audit_log ADD COLUMN user_id TEXT');
      }
      if (!await columnExists(db, 'audit_log', 'user_name')) {
        await db.execute('ALTER TABLE audit_log ADD COLUMN user_name TEXT');
      }
      if (!await columnExists(db, 'audit_log', 'device_id')) {
        await db.execute('ALTER TABLE audit_log ADD COLUMN device_id TEXT');
      }
      if (!await columnExists(db, 'audit_log', 'workspace_id')) {
        await db.execute('ALTER TABLE audit_log ADD COLUMN workspace_id TEXT');
      }
      if (!await columnExists(db, 'audit_log', 'prev_hash')) {
        await db.execute('ALTER TABLE audit_log ADD COLUMN prev_hash TEXT');
      }
      if (!await columnExists(db, 'audit_log', 'hash')) {
        await db.execute('ALTER TABLE audit_log ADD COLUMN hash TEXT');
      }
    }

    // 2. documents (created_by, updated_by, origin_device_id)
    if (await tableExists(db, 'documents')) {
      if (!await columnExists(db, 'documents', 'created_by')) {
        await db.execute('ALTER TABLE documents ADD COLUMN created_by TEXT');
      }
      if (!await columnExists(db, 'documents', 'updated_by')) {
        await db.execute('ALTER TABLE documents ADD COLUMN updated_by TEXT');
      }
      if (!await columnExists(db, 'documents', 'origin_device_id')) {
        await db.execute('ALTER TABLE documents ADD COLUMN origin_device_id TEXT');
      }
    }

    // 3. products (created_by, updated_by, origin_device_id)
    if (await tableExists(db, 'products')) {
      if (!await columnExists(db, 'products', 'created_by')) {
        await db.execute('ALTER TABLE products ADD COLUMN created_by TEXT');
      }
      if (!await columnExists(db, 'products', 'updated_by')) {
        await db.execute('ALTER TABLE products ADD COLUMN updated_by TEXT');
      }
      if (!await columnExists(db, 'products', 'origin_device_id')) {
        await db.execute('ALTER TABLE products ADD COLUMN origin_device_id TEXT');
      }
    }

    // 4. contacts (created_by, updated_by, origin_device_id)
    if (await tableExists(db, 'contacts')) {
      if (!await columnExists(db, 'contacts', 'created_by')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN created_by TEXT');
      }
      if (!await columnExists(db, 'contacts', 'updated_by')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN updated_by TEXT');
      }
      if (!await columnExists(db, 'contacts', 'origin_device_id')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN origin_device_id TEXT');
      }
    }

    // 5. document_payments (created_by, origin_device_id)
    if (await tableExists(db, 'document_payments')) {
      if (!await columnExists(db, 'document_payments', 'created_by')) {
        await db.execute('ALTER TABLE document_payments ADD COLUMN created_by TEXT');
      }
      if (!await columnExists(db, 'document_payments', 'origin_device_id')) {
        await db.execute('ALTER TABLE document_payments ADD COLUMN origin_device_id TEXT');
      }
    }

    // 6. stock_movements (created_by, origin_device_id)
    if (await tableExists(db, 'stock_movements')) {
      if (!await columnExists(db, 'stock_movements', 'created_by')) {
        await db.execute('ALTER TABLE stock_movements ADD COLUMN created_by TEXT');
      }
      if (!await columnExists(db, 'stock_movements', 'origin_device_id')) {
        await db.execute('ALTER TABLE stock_movements ADD COLUMN origin_device_id TEXT');
      }
    }

    // 7. journal_entries (created_by, origin_device_id)
    if (await tableExists(db, 'journal_entries')) {
      if (!await columnExists(db, 'journal_entries', 'created_by')) {
        await db.execute('ALTER TABLE journal_entries ADD COLUMN created_by TEXT');
      }
      if (!await columnExists(db, 'journal_entries', 'origin_device_id')) {
        await db.execute('ALTER TABLE journal_entries ADD COLUMN origin_device_id TEXT');
      }
    }

    // 8. stocktake_sessions (created_by)
    if (await tableExists(db, 'stocktake_sessions')) {
      if (!await columnExists(db, 'stocktake_sessions', 'created_by')) {
        await db.execute('ALTER TABLE stocktake_sessions ADD COLUMN created_by TEXT');
      }
    }

    // 9. businesses (updated_by)
    if (await tableExists(db, 'businesses')) {
      if (!await columnExists(db, 'businesses', 'updated_by')) {
        await db.execute('ALTER TABLE businesses ADD COLUMN updated_by TEXT');
      }
    }
  }

  /// Seeds default workspace, Owner role, Owner user, and initial app_settings (idempotent).
  static Future<void> seedAccessControlDefaults(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Workspace
    await db.rawInsert('''
      INSERT OR IGNORE INTO workspaces (id, name, created_at, updated_at)
      VALUES (?, ?, ?, ?)
    ''', [defaultWorkspaceId, 'Main Workspace', now, now]);

    // 2. System Owner Role
    await db.rawInsert('''
      INSERT OR IGNORE INTO roles (id, workspace_id, name, description, is_system, is_template)
      VALUES (?, ?, ?, ?, 1, 0)
    ''', [ownerRoleId, defaultWorkspaceId, 'المالك', 'مالك النظام بجميع الصلاحيات']);

    // 3. Default Owner User
    await db.rawInsert('''
      INSERT OR IGNORE INTO users (
        id, workspace_id, username, display_name, role_id,
        is_owner, is_active, setup_complete, failed_attempts,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, 1, 1, 0, 0, ?, ?)
    ''', [ownerUserId, defaultWorkspaceId, 'owner', 'المالك', ownerRoleId, now, now]);

    // 4. Initial app_settings
    await db.rawInsert('''
      INSERT OR IGNORE INTO app_settings (key, value) VALUES ('multi_user_enabled', '0')
    ''');
    await db.rawInsert('''
      INSERT OR IGNORE INTO app_settings (key, value) VALUES ('workspace_id', ?)
    ''', [defaultWorkspaceId]);
    await db.rawInsert('''
      INSERT OR IGNORE INTO app_settings (key, value) VALUES ('auto_lock_minutes', '5')
    ''');
    // 5. Seed template roles and permissions
    await AccessSeeder.ensureDefaults(db);

    // 6. Ensure audit log triggers and genesis anchor
    await createAuditLogTriggers(db);
    await AuditService.instance.ensureGenesis(db);
  }

  /// Creates SQLite triggers preventing UPDATE and DELETE on audit_log.
  static Future<void> createAuditLogTriggers(DatabaseExecutor db) async {
    if (await tableExists(db, 'audit_log')) {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_audit_log_no_update
        BEFORE UPDATE ON audit_log
        BEGIN
          SELECT RAISE(ABORT, 'audit_log is append-only and cannot be updated');
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_audit_log_no_delete
        BEFORE DELETE ON audit_log
        BEGIN
          SELECT RAISE(ABORT, 'audit_log is append-only and cannot be deleted');
        END;
      ''');
    }
  }

  /// Full Schema v29 upgrade routine.
  static Future<void> upgradeToSchemaV29(DatabaseExecutor db) async {
    await createAccessControlTables(db);
    await ensureAttributionColumns(db);
    await seedAccessControlDefaults(db);
  }
}
