import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../localization/app_localizations.dart';
import '../services/backup_encryption_service.dart';
import '../services/google_drive_backup_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/access/screen_access_gate.dart';
import '../widgets/backup_password_dialog.dart';
import '../widgets/responsive.dart';

class GoogleDriveBackupScreen extends StatefulWidget {
  const GoogleDriveBackupScreen({super.key});

  @override
  State<GoogleDriveBackupScreen> createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState extends State<GoogleDriveBackupScreen> {
  final GoogleDriveBackupService _service = GoogleDriveBackupService.instance;
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  bool _loading = false;
  bool _signedIn = false;
  String? _userEmail;
  List<DriveBackupFile> _backups = [];
  String? _statusMessage;
  bool _isError = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  String _mapErrorToMessage(Object error, AppLocalizations l10n) {
    final str = error.toString().toLowerCase();

    final isCancellation =
        (error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled) ||
        str.contains('cancelled') ||
        str.contains('canceled') ||
        str.contains('sign-in was cancelled') ||
        str.contains('user canceled');

    if (isCancellation) {
      return l10n.googleDriveSignInCancelled;
    }

    if (error is SocketException ||
        str.contains('socketexception') ||
        str.contains('clientexception') ||
        str.contains('timeoutexception') ||
        str.contains('failed host lookup') ||
        str.contains('network')) {
      return l10n.networkError;
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return l10n.googleDriveSignInCancelled;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return l10n.googleDriveErrorConfig;
        default:
          return l10n.googleDriveErrorAuthExpired;
      }
    }
    if (str.contains('sign-in') ||
        str.contains('authorization') ||
        str.contains('401') ||
        str.contains('403') ||
        str.contains('token')) {
      return l10n.googleDriveErrorAuthExpired;
    }
    return l10n.googleDriveErrorGeneric;
  }

  Future<void> _checkSignInStatus() async {
    setState(() => _loading = true);
    try {
      final signedIn = await _service.isSignedIn();
      if (!mounted) return;
      setState(() {
        _signedIn = signedIn;
        _userEmail = _service.currentUserEmail;
      });
      if (signedIn) {
        await _fetchBackups();
      }
    } catch (_) {
      // Ignored during status check
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
      _isError = false;
    });
    try {
      final success = await _service.signIn();
      if (!mounted) return;
      setState(() {
        _signedIn = success;
        _userEmail = _service.currentUserEmail;
      });
      if (success) {
        await _fetchBackups();
      } else {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _statusMessage = l10n.googleDriveErrorGeneric;
          _isError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final isCancellation = e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled;
      setState(() {
        _statusMessage = isCancellation
            ? l10n.googleDriveSignInCancelled
            : _mapErrorToMessage(e, l10n);
        _isError = !isCancellation;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await _service.signOut();
      if (!mounted) return;
      setState(() {
        _signedIn = false;
        _userEmail = null;
        _backups = [];
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchBackups() async {
    try {
      final list = await _service.listBackups();
      if (!mounted) return;
      setState(() => _backups = list);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _statusMessage = _mapErrorToMessage(e, l10n);
        _isError = true;
      });
    }
  }

  Future<void> _uploadBackup() async {
    final password = await BackupPasswordCreateDialog.show(context);
    if (password == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _statusMessage = l10n.googleDriveUploading;
      _isError = false;
    });

    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _loading) {
        setState(() {
          _statusMessage =
              '${l10n.googleDriveUploading}\n${l10n.backupSlowNotice}';
        });
      }
    });

    try {
      await _service.uploadCurrentBackup(
        password: password.isEmpty ? null : password,
      );
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.googleDriveUploadSuccess;
        _isError = false;
      });
      await _fetchBackups();
    } catch (e) {
      _slowTimer?.cancel();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _statusMessage = _mapErrorToMessage(e, l10n);
        _isError = true;
      });
    } finally {
      _slowTimer?.cancel();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndRestore(DriveBackupFile backup) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.googleDriveConfirmRestoreTitle),
        content: Text(
          '${l10n.googleDriveConfirmRestoreBody}\n\n${backup.name} (${backup.formattedSize})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.restore),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _statusMessage = l10n.googleDriveDownloading;
      _isError = false;
    });

    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _loading) {
        setState(() {
          _statusMessage =
              '${l10n.googleDriveDownloading}\n${l10n.backupSlowNotice}';
        });
      }
    });

    try {
      final success = await _service.restoreFromDrive(
        backup,
        context: context,
      );
      _slowTimer?.cancel();
      if (!mounted) return;
      if (success) {
        AppSnackBar.show(
          context,
          l10n.operationSuccessful,
          severity: AppSnackBarSeverity.success,
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() {
          _statusMessage = l10n.operationFailed;
          _isError = true;
        });
      }
    } on BackupUnsupportedVersionException {
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.backupUpdateRequired;
        _isError = true;
      });
    } on BackupDecryptionException {
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.backupIncorrectPassword;
        _isError = true;
      });
    } on BackupCorruptedFileException {
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.backupCorrupted;
        _isError = true;
      });
    } catch (e) {
      _slowTimer?.cancel();
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      final isFormatOrCorrupt = errStr.contains('backup') ||
          errStr.contains('format') ||
          errStr.contains('corrupt') ||
          errStr.contains('invalid') ||
          errStr.contains('table') ||
          errStr.contains('version');
      setState(() {
        _statusMessage = isFormatOrCorrupt
            ? l10n.googleDriveErrorRestoreCorrupt
            : _mapErrorToMessage(e, l10n);
        _isError = true;
      });
    } finally {
      _slowTimer?.cancel();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndDelete(DriveBackupFile backup) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.googleDriveConfirmDeleteTitle),
        content: Text(
          '${l10n.googleDriveConfirmDeleteBody}\n\n${backup.name} (${backup.formattedSize})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.googleDriveDeleteBackup),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _statusMessage = l10n.googleDriveDeleting;
      _isError = false;
    });

    try {
      await _service.deleteBackup(backup.id);
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.googleDriveDeleteSuccess;
        _isError = false;
      });
      await _fetchBackups();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _mapErrorToMessage(e, l10n);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ScreenAccessGate(
      screenType: GoogleDriveBackupScreen,
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.googleDriveTitle),
        centerTitle: true,
        actions: [
          if (_signedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.googleDriveRefresh,
              onPressed: _loading ? null : _fetchBackups,
            ),
        ],
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status and Account Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _signedIn
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          child: Icon(
                            _signedIn
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_queue_outlined,
                            color: _signedIn
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _signedIn
                                          ? (_userEmail ?? l10n.googleDriveTitle)
                                          : l10n.googleDriveTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _signedIn
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _signedIn
                                            ? Colors.green.withValues(alpha: 0.4)
                                            : cs.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      _signedIn
                                          ? l10n.googleDriveAccountConnected
                                          : l10n.googleDriveAccountDisconnected,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _signedIn
                                            ? Colors.green.shade800
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.googleDriveSubtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_signedIn)
                      FilledButton.icon(
                        onPressed: _loading ? null : _signIn,
                        icon: const Icon(Icons.login),
                        label: Text(l10n.googleDriveConnect),
                      )
                    else
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isNarrow = constraints.maxWidth < 340;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  onPressed: _loading ? null : _uploadBackup,
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: Text(l10n.googleDriveUploadNow),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _loading ? null : _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: Text(l10n.googleDriveDisconnect),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _loading ? null : _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: Text(l10n.googleDriveDisconnect),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _uploadBackup,
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: Text(l10n.googleDriveUploadNow),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? cs.errorContainer : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isError
                        ? cs.onErrorContainer
                        : cs.onPrimaryContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_signedIn) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  l10n.googleDriveBackupListHeader,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (_backups.isEmpty)
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.googleDriveNoBackups,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.googleDriveEmptySubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._backups.map(
                  (b) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isCompact = constraints.maxWidth < 340;
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.surfaceContainerHighest,
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: cs.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        b.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        '${b.formattedSize} • ${_dateFmt.format(b.modifiedTime.toLocal())}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              FilledButton.tonal(
                                onPressed: _loading ? null : () => _confirmAndRestore(b),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 8 : 12,
                                  ),
                                ),
                                child: Text(l10n.restore),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: cs.error,
                                  size: 20,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.googleDriveDeleteBackup,
                                onPressed: _loading ? null : () => _confirmAndDelete(b),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}
