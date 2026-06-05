import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:shiftchart/models/hpr_record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shiftchart/services/pdf_service.dart';
import 'package:shiftchart/screens/pdf_viewer_screen.dart';
import 'package:shiftchart/theme/AppColors.dart';

class HPRHistoryScreen extends StatelessWidget {
  final bool showOnlyBookmarked;
  const HPRHistoryScreen({super.key, this.showOnlyBookmarked = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(showOnlyBookmarked ? 'Starred Records' : 'Patient History (HPR)'),
      ),
      body: ValueListenableBuilder<Box<HPRRecord>>(
        valueListenable: Hive.box<HPRRecord>('hpr_history').listenable(),
        builder: (context, box, _) {
          final allRecords = box.values.toList().reversed.toList();
          final records = showOnlyBookmarked 
              ? allRecords.where((r) => r.isBookmarked).toList() 
              : allRecords;

          if (records.isEmpty) {
            return _buildEmptyState(context);
          }

          // Group by date
          final grouped = <String, List<HPRRecord>>{};
          for (var record in records) {
            final dateStr = DateFormat('MMMM dd, yyyy').format(record.dischargeDate);
            grouped.putIfAbsent(dateStr, () => []).add(record);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final date = grouped.keys.elementAt(index);
              final dateRecords = grouped[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                    child: Text(
                      date,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...dateRecords.map((record) => _buildRecordCard(context, record)),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showOnlyBookmarked ? Icons.star_outline : Icons.history_edu_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            showOnlyBookmarked ? 'No starred records found' : 'No archived records yet',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, HPRRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          record.patientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Room ${record.roomNumber} • ${record.entries.length} entries'),
            ValueListenableBuilder<bool>(
              valueListenable: use24HourFormatNotifier,
              builder: (context, use24h, _) {
                String timeString;
                if (use24h) {
                  timeString = DateFormat('HH:mm').format(record.dischargeDate);
                } else {
                  timeString = DateFormat('h:mm a').format(record.dischargeDate);
                }
                return Text(
                  'Discharged at $timeString',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                );
              },
            ),
          ],
        ),
        trailing: record.isBookmarked 
            ? Icon(Icons.star, color: Theme.of(context).colorScheme.primary, size: 20)
            : const Icon(Icons.chevron_right),
        onTap: () => _showRecordDetails(context, record),
      ),
    );
  }

  void _showRecordDetails(BuildContext context, HPRRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    StatefulBuilder(
                      builder: (context, setSheetState) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Clinical Audit Report',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                record.isBookmarked ? Icons.star : Icons.star_border,
                                color: record.isBookmarked ? Theme.of(context).colorScheme.primary : null,
                                size: 22,
                              ),
                              onPressed: () async {
                                await _toggleBookmark(context, record);
                                setSheetState(() {}); // Force icon update in sheet
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 22),
                              onPressed: () => _shareRecord(record),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Patient: ${record.patientName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    Text('ID: ${record.patientId} • Room: ${record.roomNumber}'),
                    const Divider(height: 32),
                    if (record.notes != null && record.notes!.isNotEmpty) ...[
                      _buildNotesSection(context, record.notes!),
                      const Divider(height: 32),
                    ],
                    ...record.entries.map((entry) => _buildEntryItem(context, entry)),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      onTap: () => _viewPdf(context, record),
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'View as PDF Document',
                      width: double.infinity,
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'End of Record • Non-Editable Archive',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryItem(BuildContext context, HPREntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: use24HourFormatNotifier,
                builder: (context, use24h, _) {
                  String timeString;
                  if (use24h) {
                    timeString = DateFormat('HH:mm').format(entry.time);
                  } else {
                    timeString = DateFormat('h:mm a').format(entry.time);
                  }
                  return Text(
                    timeString,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Container(
                width: 2,
                height: 40,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Text(
                    entry.report,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, String notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'CLINICAL NOTES / SBAR',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Text(
            notes,
            style: GoogleFonts.manrope(
              fontSize: 15,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleBookmark(BuildContext context, HPRRecord record) async {
    record.isBookmarked = !record.isBookmarked;
    await record.save();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(record.isBookmarked ? 'Record added to Starred' : 'Record removed from Starred'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _viewPdf(BuildContext context, HPRRecord record) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing PDF...'), duration: Duration(milliseconds: 500)),
    );

    try {
      // Generate temporary PDF for viewing
      final path = await PdfService.saveHprPdf(record);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              filePath: path,
              title: '${record.patientId} - ${record.patientName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  void _shareRecord(HPRRecord record) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('CLINICAL AUDIT REPORT');
    buffer.writeln('=====================');
    buffer.writeln('Patient: ${record.patientName}');
    buffer.writeln('ID: ${record.patientId}');
    buffer.writeln('Room: ${record.roomNumber}');
    buffer.writeln('Discharge: ${DateFormat('yyyy-MM-dd HH:mm').format(record.dischargeDate)}');
    if (record.notes != null && record.notes!.isNotEmpty) {
      buffer.writeln('\nCLINICAL NOTES:');
      buffer.writeln(record.notes);
    }
    buffer.writeln('=====================\n');

    for (var entry in record.entries) {
      buffer.writeln('[${DateFormat('HH:mm').format(entry.time)}] ${entry.name}');
      buffer.writeln('Report: ${entry.report}\n');
    }

    buffer.writeln('End of Record • Non-Editable Archive');
    
    Share.share(buffer.toString(), subject: 'HPR Record - ${record.patientName}');
  }
}
