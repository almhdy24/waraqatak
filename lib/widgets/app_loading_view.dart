import 'package:flutter/material.dart';
import 'app_design_tokens.dart';

/// Standard calm loading indicator with an optional informational message.
class AppLoadingView extends StatelessWidget {
  final String? message;

  const AppLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: cs.primary,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppDesignTokens.space16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
