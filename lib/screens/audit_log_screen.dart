import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiftchart/theme/AppColors.dart';

import '../models/audit_entry.dart';
import '../services/audit_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  AuditCategory? _selectedCategory;
  bool _isCompactView = false;

  void _showAuditDetails(AuditEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AuditDetailsSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Audit Log',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isCompactView = !_isCompactView),
            icon: Icon(_isCompactView ? Icons.view_agenda_outlined : Icons.view_headline_rounded),
            tooltip: _isCompactView ? 'Switch to Detailed View' : 'Switch to Compact View',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...AuditCategory.values.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: c.label,
                    selected: _selectedCategory == c,
                    color: c.color(colorScheme),
                    onTap: () => setState(() => _selectedCategory = c),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<AuditEntry>>(
        future: AuditService.getEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No audit entries.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final entries = snapshot.data!
              .where((e) => _selectedCategory == null || e.category == _selectedCategory)
              .toList();

          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No entries in this category.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => SizedBox(height: _isCompactView ? 4 : 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _isCompactView 
                  ? _AuditEntryCompact(
                      entry: entry, 
                      onTap: () => _showAuditDetails(entry),
                    )
                  : _AuditEntryCard(
                      entry: entry,
                      onTap: () => _showAuditDetails(entry),
                    );
            },
          );
        },
      ),
    );
  }
}

class _AuditEntryCompact extends StatelessWidget {
  final AuditEntry entry;
  final VoidCallback onTap;

  const _AuditEntryCompact({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = entry.category.color(colorScheme);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            // Action Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIconForAction(entry.action), size: 14, color: color),
          ),
          const SizedBox(width: 12),
          
          // Action Label & Primary Data
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.actionLabel,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (entry.data.containsKey('name') || entry.data.containsKey('medication'))
                  Text(
                    entry.data['name'] ?? entry.data['medication'] ?? '',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Time & Result
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimeOnly(entry.timestamp),
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: entry.outcome ? Colors.green : colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  IconData _getIconForAction(AuditAction action) {
    return switch (action.index) {
      0 || 1 || 2 || 3 || 4 => Icons.person_outline, // Patient
      5 || 6 || 7 || 8 || 9 => Icons.medication_outlined, // Medication
      10 || 11 || 12 || 13 || 14 => Icons.assignment_outlined, // Task
      15 || 16 || 17 => Icons.water_drop_outlined, // IV
      18 || 19 => Icons.history_edu_outlined, // HPR
      20 || 21 => Icons.storage_outlined, // Data
      22 || 23 => Icons.settings_outlined, // App/Settings
      _ => Icons.info_outline,
    };
  }

  String _formatTimeOnly(DateTime dt) {
    final use24h = use24HourFormatNotifier.value;
    if (use24h) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    }
  }
}

class _AuditEntryCard extends StatelessWidget {
  final AuditEntry entry;
  final VoidCallback onTap;

  const _AuditEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = entry.category.color(colorScheme);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.actionLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(entry.timestamp),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Data fields (limited in card view to prevent huge cards)
            ...entry.data.entries.take(3).map((field) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      _formatKey(field.key),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${field.value}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
            if (entry.data.length > 3)
              Text(
                '+ ${entry.data.length - 3} more details...',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),

            const Divider(height: 20),

            // Footer — nurse + device (Fixed with Wrap to prevent overflow)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      entry.nurseName,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_android, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      entry.deviceModel,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.outcome ? Icons.check_circle_outline : Icons.error_outline,
                      size: 14,
                      color: entry.outcome ? Colors.green : colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.outcome ? 'Success' : 'Failed',
                      style: textTheme.labelSmall?.copyWith(
                        color: entry.outcome ? Colors.green : colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    // camelCase to Title Case
    final spaced = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
          (m) => ' ${m.group(0)}',
    );
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}:';
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDay = DateTime(dt.year, dt.month, dt.day);

    String dateStr;
    if (entryDay == today) {
      dateStr = 'Today';
    } else if (entryDay == yesterday) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    final use24h = use24HourFormatNotifier.value;
    String timeStr;
    if (use24h) {
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    }

    return '$dateStr $timeStr';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = color ?? colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? activeColor : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AuditDetailsSheet extends StatelessWidget {
  final AuditEntry entry;

  const _AuditDetailsSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final color = entry.category.color(colorScheme);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconForAction(entry.action), color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.actionLabel,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _formatFullTimestamp(entry.timestamp),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (entry.outcome ? Colors.green : colorScheme.error).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.outcome ? 'SUCCESS' : 'FAILED',
                  style: textTheme.labelSmall?.copyWith(
                    color: entry.outcome ? Colors.green : colorScheme.error,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          Text(
            'EVENT DETAILS',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          ...entry.data.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    _formatKey(e.key),
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${e.value}',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )),
          
          const Divider(height: 40),
          
          Text(
            'TRACEABILITY',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildTraceRow(Icons.person_outline, 'Nurse Name', entry.nurseName, colorScheme, textTheme),
          _buildTraceRow(Icons.phone_android, 'Device Model', entry.deviceModel, colorScheme, textTheme),
          _buildTraceRow(Icons.fingerprint, 'Device Identifier', entry.deviceId, colorScheme, textTheme),
          _buildTraceRow(Icons.tag, 'Audit ID', entry.id, colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildTraceRow(IconData icon, String label, String value, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(
              value, 
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullTimestamp(DateTime dt) {
    final use24h = use24HourFormatNotifier.value;
    final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    String time;
    if (use24h) {
      time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      time = '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    }
    return '$date • $time';
  }
}

IconData _getIconForAction(AuditAction action) {
  return switch (action.index) {
    0 || 1 || 2 || 3 || 4 => Icons.person_outline, // Patient
    5 || 6 || 7 || 8 || 9 => Icons.medication_outlined, // Medication
    10 || 11 || 12 || 13 || 14 => Icons.assignment_outlined, // Task
    15 || 16 || 17 => Icons.water_drop_outlined, // IV
    18 || 19 => Icons.history_edu_outlined, // HPR
    20 || 21 => Icons.storage_outlined, // Data
    22 || 23 => Icons.settings_outlined, // App/Settings
    _ => Icons.info_outline,
  };
}

String _formatKey(String key) {
  if (key.isEmpty) return '';
  // camelCase to Title Case
  final spaced = key.replaceAllMapped(
    RegExp(r'([A-Z])'),
        (m) => ' ${m.group(0)}',
  );
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}:';
}
