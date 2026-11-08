import 'package:flutter/foundation.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../../models/app_user.dart';

/// Non-widget singleton managing current session, authentication state, and cached permissions.
class SessionManager extends ChangeNotifier {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  bool _initialized = false;
  bool _isMultiUserEnabled = false;
  int _autoLockMinutes = 5;

  AppUser? _currentUser;
  Set<String> _cachedPermissions = {};
  bool _isLocked = false;
  DateTime _lastActivity = DateTime.now();

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
  int get autoLockMinutes => _autoLockMinutes;
  bool get isLocked => _isMultiUserEnabled && _isLocked;
  DateTime get lastActivity => _lastActivity;

  /// Returns current user, or implicit Owner in single-user mode.
  AppUser? get currentUser {
    if (!_isMultiUserEnabled) return _defaultOwner;
    return _currentUser;
  }

  /// Cached permissions set.
  Set<String> get permissions => _cachedPermissions;

  /// Checks if current user has permission for [key].
  /// In single-user mode or for Owner, ALWAYS returns true immediately.
  bool can(String key) {
    if (!_isMultiUserEnabled) return true;
    final user = _currentUser;
    if (user == null) return false;
    if (user.isOwner) return true;
    return _cachedPermissions.contains(key);
  }

  /// Initializes session state from database.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final settings = await db.query(
        'app_settings',
        where: "key IN ('multi_user_enabled', 'auto_lock_minutes')",
      );
      final map = {for (final s in settings) s['key']: s['value']};

      _isMultiUserEnabled = map['multi_user_enabled']?.toString() == '1';
      _autoLockMinutes =
          int.tryParse(map['auto_lock_minutes']?.toString() ?? '5') ?? 5;

      if (_isMultiUserEnabled) {
        // Multi-user is enabled: starts in locked / logged-out state
        _currentUser = null;
        _isLocked = true;
      } else {
        _currentUser = _defaultOwner;
        _isLocked = false;
      }
      _initialized = true;
      notifyListeners();
    } catch (_) {
      // In case DB is not yet available, fallback to single-user mode safely
      _isMultiUserEnabled = false;
      _currentUser = _defaultOwner;
      _isLocked = false;
    }
  }

  /// Enables or disables multi-user mode.
  Future<void> setMultiUserEnabled(bool enabled) async {
    _isMultiUserEnabled = enabled;
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('multi_user_enabled', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [enabled ? '1' : '0']);

    if (!enabled) {
      _currentUser = _defaultOwner;
      _isLocked = false;
      _cachedPermissions = {};
    } else {
      _isLocked = false;
    }
    notifyListeners();
  }

  /// Sets auto-lock duration in minutes (0 = disabled).
  Future<void> setAutoLockMinutes(int minutes) async {
    _autoLockMinutes = minutes;
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('auto_lock_minutes', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [minutes.toString()]);
    notifyListeners();
  }

  /// Sets the active user session and updates cached permissions.
  void setSession(AppUser user, Set<String> permissions) {
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
      notifyListeners();
    }
  }

  /// Unlocks the session.
  void unlock(AppUser user, Set<String> permissions) {
    _currentUser = user;
    _cachedPermissions = permissions;
    _isLocked = false;
    _lastActivity = DateTime.now();
    notifyListeners();
  }

  /// Logs out current user.
  void logout() {
    if (!_isMultiUserEnabled) return;
    _currentUser = null;
    _cachedPermissions = {};
    _isLocked = true;
    notifyListeners();
  }

  /// Records user activity (touches, keystrokes) to prevent idle auto-lock.
  void recordActivity() {
    _lastActivity = DateTime.now();
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
}
