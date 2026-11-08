import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import 'access_guard.dart';
import 'audit_service.dart';
import 'permission_registry.dart';

/// Non-widget singleton managing current session, authentication state, and cached permissions.
class SessionManager extends ChangeNotifier {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  /// Global navigator key to pop open sub-screens to root when locking.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _initialized = false;
  bool _isMultiUserEnabled = false;
  bool _securityUnverified = false;
  int _autoLockMinutes = 5;

  AppUser? _currentUser;
  Set<String> _cachedPermissions = {};
  bool _isLocked = false;
  DateTime _lastActivity = DateTime.now();
  Timer? _inactivityTimer;

  /// Default synthetic Owner user used when multi-user mode is disabled.
  static final AppUser _defaultOwner = AppUser(
    id: AccessDao.ownerUserId,
    workspaceId: AccessDao.defaultWorkspaceId,
    username: 'owner',
    displayName: 'المالك',
    roleId: AccessDao.ownerRoleId,
    isOwner: true,
    isActive: true,
    setupComplete: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  /// Fast-path boolean flag for single-user mode.
  bool get isMultiUserEnabled => _isMultiUserEnabled;
  bool get isSecurityUnverified => _securityUnverified;
  int get autoLockMinutes => _autoLockMinutes;
  bool get isLocked => _isMultiUserEnabled && (_isLocked || _securityUnverified);
  DateTime get lastActivity => _lastActivity;

  /// Returns current user, or implicit Owner in single-user mode.
  AppUser? get currentUser {
    if (!_isMultiUserEnabled) return _defaultOwner;
    return _currentUser;
  }

  /// Whether the current session belongs to the Owner.
  bool get isOwnerSession => currentUser?.isOwner == true;

  /// Cached permissions set.
  Set<String> get permissions => _cachedPermissions;
  Set<String> get cachedPermissions => _cachedPermissions;

  /// Checks if current user has permission for [key].
  /// In multi-user mode, returns false when locked or when no user is logged in.
  /// In single-user mode, returns true immediately.
  bool can(String key) {
    if (!_isMultiUserEnabled) return true;
    if (_isLocked || _securityUnverified || _currentUser == null) return false;
    final user = _currentUser!;
    if (user.isOwner) return true;
    return _cachedPermissions.contains(key);
  }

  /// Initializes session state from database.
  ///
  /// FAILS CLOSED: Never downgrades to single-user mode or implicit Owner on error.
  Future<void> init() async {
    if (_initialized) return;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final db = await DatabaseHelper.instance.database;
        final settings = await db.query(
          'app_settings',
          where: "key IN ('multi_user_enabled', 'auto_lock_minutes')",
        );
        final map = {for (final s in settings) s['key']: s['value']};

        final rawEnabled = map['multi_user_enabled']?.toString();
        // If 'multi_user_enabled' is present and equals '1', multi-user is active.
        // If absent or '0', single-user fast path is active.
        _isMultiUserEnabled = rawEnabled == '1';
        _autoLockMinutes =
            int.tryParse(map['auto_lock_minutes']?.toString() ?? '5') ?? 5;

        _securityUnverified = false;
        if (_isMultiUserEnabled) {
          _currentUser = null;
          _cachedPermissions = {};
          _isLocked = true;
        } else {
          _currentUser = _defaultOwner;
          _cachedPermissions = {};
          _isLocked = false;
        }
        _initialized = true;
        _startInactivityTimer();
        notifyListeners();
        return;
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 100 * (attempt + 1)),
          );
          continue;
        }
        // FAILED after retries: FAIL CLOSED!
        _isMultiUserEnabled = true;
        _securityUnverified = true;
        _currentUser = null;
        _cachedPermissions = {};
        _isLocked = true;
        _initialized = true;
        notifyListeners();
      }
    }
  }

  /// Retries initialization after a failed security settings load.
  Future<void> retryInit() async {
    _initialized = false;
    await init();
  }

  /// Enables or disables multi-user mode.
  ///
  /// Writes to database FIRST inside a transaction with its audit event.
  /// On enable, loads the real Owner user and establishes session without lock bounce.
  Future<void> setMultiUserEnabled(bool enabled) async {
    final db = await DatabaseHelper.instance.database;

    AppUser? realOwner;
    if (enabled) {
      final rows = await db.query(
        'users',
        where: 'is_owner = 1 AND is_active = 1',
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError(
          'Cannot enable multi-user mode: no active owner account found',
        );
      }
      realOwner = AppUser.fromMap(rows.first);
    }

    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.rawInsert('''
        INSERT INTO app_settings (key, value) VALUES ('multi_user_enabled', ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''', [enabled ? '1' : '0']);

      if (enabled && realOwner != null) {
        await txn.update(
          'users',
          {
            'last_login_at': now,
            'failed_attempts': 0,
            'locked_until': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [realOwner.id],
        );
      }

      await AuditService.instance.logEvent(
        txn,
        enabled ? 'multi_user_enabled' : 'multi_user_disabled',
        entityType: 'settings',
        details:
            enabled ? 'Multi-user mode enabled' : 'Multi-user mode disabled',
      );
    });

    _isMultiUserEnabled = enabled;
    _securityUnverified = false;
    if (enabled) {
      final updatedOwner = realOwner!.copyWith(
        lastLoginAt: DateTime.parse(now),
        failedAttempts: 0,
        lockedUntil: null,
      );
      _currentUser = updatedOwner;
      _cachedPermissions = PermissionRegistry.allKeys;
      _isLocked = false;
      _lastActivity = DateTime.now();
      _startInactivityTimer();
    } else {
      _currentUser = _defaultOwner;
      _cachedPermissions = {};
      _isLocked = false;
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }
    notifyListeners();
  }

  /// In-memory setter for test suites.
  @visibleForTesting
  void setMultiUserEnabledForTesting(bool enabled) {
    _isMultiUserEnabled = enabled;
    _securityUnverified = false;
    if (!enabled) {
      _currentUser = _defaultOwner;
      _isLocked = false;
      _cachedPermissions = {};
    } else {
      _currentUser = null;
      _isLocked = true;
      _cachedPermissions = {};
    }
    notifyListeners();
  }

  /// Sets auto-lock duration in minutes (0 = disabled).
  Future<void> setAutoLockMinutes(int minutes) async {
    if (isMultiUserEnabled && !isOwnerSession) {
      throw const PermissionDeniedException('owner_only: auto_lock_minutes');
    }
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('auto_lock_minutes', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [minutes.toString()]);
    _autoLockMinutes = minutes;
    _startInactivityTimer();
    notifyListeners();
  }

  /// Sets the active user session and updates cached permissions.
  ///
  /// Verifies user is active and not locked.
  void setSession(AppUser user, Set<String> permissions) {
    if (!user.isActive) {
      throw StateError('Cannot establish session for inactive user');
    }
    if (user.isLocked) {
      throw StateError('Cannot establish session for locked user');
    }
    _currentUser = user;
    _cachedPermissions = permissions;
    _isLocked = false;
    _lastActivity = DateTime.now();
    notifyListeners();
  }

  /// Refreshes cached permissions for the current user.
  void updateCachedPermissions(Set<String> permissions) {
    _cachedPermissions = permissions;
    notifyListeners();
  }

  /// Locks the session.
  void lock() {
    if (!_isMultiUserEnabled) return;
    if (!_isLocked) {
      _isLocked = true;
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      notifyListeners();
    }
  }

  /// Unlocks the session. Delegates directly to [setSession].
  void unlock(AppUser user, Set<String> permissions) {
    setSession(user, permissions);
  }

  /// Logs out current user.
  void logout() {
    if (!_isMultiUserEnabled) return;
    _currentUser = null;
    _cachedPermissions = {};
    _isLocked = true;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    notifyListeners();
  }

  /// Records user activity (touches, keystrokes) to prevent idle auto-lock.
  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_isMultiUserEnabled || _autoLockMinutes <= 0) return;
    _inactivityTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkInactivityLock();
    });
  }

  /// Checks if idle inactivity duration has passed, and locks if needed.
  bool checkInactivityLock() {
    if (!_isMultiUserEnabled || _isLocked || _autoLockMinutes <= 0) {
      return false;
    }
    final now = DateTime.now();
    if (now.difference(_lastActivity).inMinutes >= _autoLockMinutes) {
      lock();
      return true;
    }
    return false;
  }

  /// Resets session state for unit test isolation.
  @visibleForTesting
  void resetForTesting() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _initialized = false;
    _isMultiUserEnabled = false;
    _securityUnverified = false;
    _autoLockMinutes = 5;
    _currentUser = _defaultOwner;
    _cachedPermissions = {};
    _isLocked = false;
    _lastActivity = DateTime.now();
  }
}
