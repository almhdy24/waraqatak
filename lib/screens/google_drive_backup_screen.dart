import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../localization/app_localizations.dart';
import '../services/google_drive_backup_service.dart';
import '../widgets/responsive.dart';

class GoogleDriveBackupScreen extends StatefulWidget {
  const GoogleDriveBackupScreen({super.key});

  @override
  State<GoogleDriveBackupScreen> createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState extends State<GoogleDriveBackupScreen> {
  final GoogleDriveBackupService _service = GoogleDriveBackupService.instance;

  bool _loading = false;
  bool _signedIn = false;
  String? _userEmail;
  List<DriveBackupFile> _backups = [];
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  String _mapErrorToMessage(Object error, AppLocalizations l10n) {
    final str = error.toString().toLowerCase();
    if (error is SocketException ||
        str.contains('socketexception') ||
        str.contains('clientexception') ||
        str.contains('timeoutexception') ||
        str.contains('failed host lookup') ||
        str.contains('network')) {
      return l10n.networkError;
    }
    if (error is GoogleSignInException ||
        str.contains('sign-in') ||
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
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _statusMessage = _mapErrorToMessage(e, l10n);
        _isError = true;
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _statusMessage = l10n.googleDriveUploading;
      _isError = false;
    });

    try {
      await _service.uploadCurrentBackup();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.googleDriveUploadSuccess;
        _isError = false;
      });
      await _fetchBackups();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _statusMessage = _mapErrorToMessage(e, l10n);
        _isError = true;
      });
    } finally {
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

    try {
      final success = await _service.restoreFromDrive(backup);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.operationSuccessful)));
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() {
          _statusMessage = l10n.operationFailed;
          _isError = true;
        });
      }
    } catch (e) {
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.googleDriveTitle), centerTitle: true),
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
                          backgroundColor: cs.primaryContainer,
                          child: Icon(
                            Icons.cloud_sync_outlined,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _signedIn
                                    ? (_userEmail ?? l10n.googleDriveTitle)
                                    : l10n.googleDriveTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                      Row(
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
                  l10n.googleDriveSelectBackup,
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l10n.googleDriveNoBackups,
                        style: TextStyle(color: cs.onSurfaceVariant),
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
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(
                        b.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${b.formattedSize} • ${b.modifiedTime.toLocal().toString().split('.').first}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _confirmAndRestore(b),
                        child: Text(l10n.restore),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
