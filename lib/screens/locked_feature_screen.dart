import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'activation_screen.dart';
import 'transparency_screen.dart';
import '../widgets/responsive.dart';
import '../widgets/support_guidance_card.dart';

/// Neutral locked screen shown when a Pro feature is accessed without an
/// active trial or valid activation. Contains only approved copy — no
/// pricing, ordering, or payment references.
class LockedFeatureScreen extends StatelessWidget {
  const LockedFeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.proFeatureTitle),
        centerTitle: true,
      ),
      body: ResponsiveCenter(child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline,
                    size: 40, color: cs.primary),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.proFeaturesActivation,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.getActivationKeyInfo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: cs.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.freeDataAlwaysAvailable,
                        style: TextStyle(
                            fontSize: 13, color: Colors.green.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ActivationScreen()),
                    );
                    if (result == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: Text(l10n.enterActivationKeyAction),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransparencyScreen()),
                ),
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(l10n.seeFreeVsPro),
              ),
              const SizedBox(height: 12),
              const SupportGuidanceCard(compact: true),
              const SizedBox(height: 16),
            ],
          ),
        ),
      )),
    );
  }
}
