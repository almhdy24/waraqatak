import 'dart:convert';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../services/access/access_error.dart';
import '../../services/access/access_policy.dart';
import '../../services/access/audit_service.dart';
import '../../services/access/screen_access_policy.dart';
import '../../services/access/session_manager.dart';
import 'access_denied_view.dart';

/// Screen-level security gate wrapping protected screen bodies.
///
/// If authorized, renders [child].
/// If unauthorized, intercepts rendering with [AccessDeniedView].
class ScreenAccessGate extends StatefulWidget {
  final Type screenType;
  final Widget child;
  final bool? allowOverride;

  const ScreenAccessGate({
    super.key,
    required this.screenType,
    required this.child,
    this.allowOverride,
  });

  @override
  State<ScreenAccessGate> createState() => _ScreenAccessGateState();
}

class _ScreenAccessGateState extends State<ScreenAccessGate> {
  AccessErrorCode? _lastLoggedDecision;

  void _logDenialIfNeeded(PolicyResult decision) {
    if (!decision.isAllowed &&
        decision.decision != null &&
        _lastLoggedDecision != decision.decision) {
      _lastLoggedDecision = decision.decision;
      DatabaseHelper.instance.database.then((db) {
        AuditService.instance
            .logEvent(
              db,
              'privilege_escalation_denied',
              entityType: 'screen',
              details: jsonEncode({
                'screen': widget.screenType.toString(),
                'decision': decision.decision?.name,
                'permissionKey': decision.permissionKey,
                'reason': decision.debugReason,
              }),
            )
            .catchError((_) {});
      }).catchError((_) {});
    } else if (decision.isAllowed) {
      _lastLoggedDecision = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SessionManager.instance.isMultiUserEnabled || widget.allowOverride == true) {
      return widget.child;
    }

    final decision = ScreenAccessPolicy.evaluate(widget.screenType);
    if (decision.isAllowed) {
      _lastLoggedDecision = null;
      return widget.child;
    }

    _logDenialIfNeeded(decision);

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accessDeniedTitle),
        centerTitle: true,
      ),
      body: AccessDeniedView(
        screenType: widget.screenType,
        decision: decision.decision ?? AccessErrorCode.missingPermission,
        permissionKey: decision.permissionKey,
        debugReason: decision.debugReason,
      ),
    );
  }
}
