import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_localizations.dart';

class UrlLauncherUtils {
  static Future<void> launch(
    BuildContext context,
    String url, {
    bool external = true,
  }) async {
    await launchUri(context, Uri.parse(url), external: external);
  }

  static Future<void> launchUri(
    BuildContext context,
    Uri uri, {
    bool external = true,
  }) async {
    try {
      if (!await canLaunchUrl(uri)) {
        if (context.mounted) _showError(context);
        return;
      }
      await launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    } catch (_) {
      if (context.mounted) _showError(context);
    }
  }

  static void _showError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).operationFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
