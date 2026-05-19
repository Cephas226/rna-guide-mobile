// ============================================================
// RNA Guide - Widgets communs
// Composants réutilisables dans toute l'application
// ============================================================

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

// ── Loading Skeleton ──────────────────────────────────────────

class RnaShimmerCard extends StatelessWidget {
  final double height;
  const RnaShimmerCard({super.key, this.height = 100});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[200]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

// ── État vide ─────────────────────────────────────────────────

class RnaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const RnaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 80, color: AppTheme.primary.withOpacity(0.25)),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700,
        ), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          textAlign: TextAlign.center),
        if (buttonLabel != null && onButton != null) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onButton,
            icon: const Icon(Icons.add),
            label: Text(buttonLabel!),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
          ),
        ],
      ]),
    ),
  );
}

// ── Statut sync badge ─────────────────────────────────────────

class SyncBadge extends StatelessWidget {
  final String status;
  const SyncBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.syncStatusColor(status);
    final label = switch (status) {
      'SYNCED'   => 'Synchronisé',
      'PENDING'  => 'En attente',
      'CONFLICT' => 'Conflit',
      'DELETED'  => 'Supprimé',
      _           => status,
    };
    final icon = switch (status) {
      'SYNCED'   => Icons.cloud_done,
      'PENDING'  => Icons.cloud_upload,
      'CONFLICT' => Icons.warning_amber,
      _           => Icons.cloud_off,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Carte info ────────────────────────────────────────────────

class RnaInfoCard extends StatelessWidget {
  final String title;
  final Map<String, String> items;
  final Color? color;

  const RnaInfoCard({super.key, required this.title, required this.items, this.color});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              color: color ?? AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 14,
            color: color ?? AppTheme.primary,
          )),
        ]),
        const SizedBox(height: 12),
        ...items.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(flex: 2, child: Text(e.key,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
            Expanded(flex: 3, child: Text(e.value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ]),
        )),
      ]),
    ),
  );
}

// ── Metric tile ───────────────────────────────────────────────

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.15)),
      ),
      child: Column(children: [
        Icon(icon, color: c, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800, color: c,
        )),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          fontSize: 11, color: AppTheme.textSecondary,
        ), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Bouton primaire avec loading ──────────────────────────────

class RnaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool outlined;
  final Color? color;

  const RnaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white,
            ),
          )
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label),
          ]);

    if (outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color ?? AppTheme.primary),
          foregroundColor: color ?? AppTheme.primary,
          minimumSize: const Size(double.infinity, 52),
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppTheme.primary,
        minimumSize: const Size(double.infinity, 52),
      ),
      child: child,
    );
  }
}

// ── Section header ────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: const TextStyle(
        fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary,
      ))),
      if (action != null && onAction != null)
        TextButton(onPressed: onAction, child: Text(action!)),
    ]),
  );
}

// ── Snackbar helpers ──────────────────────────────────────────

class RnaSnackbar {
  static void success(String message) => _show(message, AppTheme.success, Icons.check_circle);
  static void error(String message) => _show(message, AppTheme.error, Icons.error_outline);
  static void info(String message) => _show(message, AppTheme.info, Icons.info_outline);
  static void warning(String message) => _show(message, AppTheme.warning, Icons.warning_amber);

  static void _show(String message, Color color, IconData icon) {
    // Nécessite BuildContext — utilisation via Get.snackbar
  }
}

// ── Dialog de confirmation ────────────────────────────────────

class RnaConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color? confirmColor;

  const RnaConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmer',
    this.confirmColor,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RnaConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    content: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Annuler'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmColor ?? AppTheme.primary,
        ),
        child: Text(confirmLabel),
      ),
    ],
  );
}
