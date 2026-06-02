import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/models.dart';

class KidsZoneLogo extends StatelessWidget {
  const KidsZoneLogo({
    super.key,
    this.compact = false,
    this.centered = false,
  });

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final titleStyle = (compact
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.headlineMedium)
        ?.copyWith(
      fontWeight: FontWeight.w900,
      color: KidsZoneColors.ink,
      letterSpacing: 0,
    );
    final mark = _KidsZoneMark(size: compact ? 34 : 54);
    final title = Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Kids Zone', style: titleStyle),
        if (!compact)
          Text(
            'Safe learning social',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF5C6B7A),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
          ),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        mark,
        const SizedBox(width: 10),
        Flexible(child: title),
      ],
    );
  }
}

class _KidsZoneMark extends StatelessWidget {
  const _KidsZoneMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KidsZoneColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KidsZoneColors.line),
          boxShadow: [
            BoxShadow(
              color: KidsZoneColors.sky.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.18,
              left: size * 0.18,
              child: _dot(size * 0.16, KidsZoneColors.sun),
            ),
            Positioned(
              right: size * 0.18,
              top: size * 0.23,
              child: _dot(size * 0.13, KidsZoneColors.leaf),
            ),
            Icon(
              Icons.psychology_alt_outlined,
              color: KidsZoneColors.sky,
              size: size * 0.52,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(double size, Color color) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BlockedAccountScreen extends StatelessWidget {
  const BlockedAccountScreen({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 44),
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?action,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color statusColor(ContentStatus status, ColorScheme scheme) {
  return switch (status) {
    ContentStatus.approved => Colors.green.shade700,
    ContentStatus.pending => scheme.primary,
    ContentStatus.flagged => Colors.orange.shade800,
    ContentStatus.rejected => scheme.error,
  };
}
