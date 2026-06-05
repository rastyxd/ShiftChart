import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:hive/hive.dart';
import 'package:shiftchart/models/hpr_record.dart';
import 'package:shiftchart/models/patient.dart';

class PdfService {
  static Future<String> _getSafePath(String filename) async {
    final directory = await getApplicationSupportDirectory();
    final path = '${directory.path}/Internal/PatientRecords';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '$path/$filename';
  }

  static Future<String> _savePdfFile(pw.Document pdf, String filename) async {
    final fullPath = await _getSafePath(filename);
    final file = File(fullPath);
    await file.writeAsBytes(await pdf.save());
    return fullPath;
  }

  /// Generates and saves a PDF for a single archived HPR record.
  static Future<String> saveHprPdf(HPRRecord record) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ShiftChart', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('Secure Clinical Audit System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Clinical Audit Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 5),
                pw.Text(
                  'CONFIDENTIAL: This document contains Protected Health Information (PHI) and is intended for clinical audit purposes only.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PATIENT INFORMATION', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoField('Name', record.patientName)),
                      pw.Expanded(child: _buildInfoField('Patient ID', record.patientId)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoField('Room', record.roomNumber)),
                      pw.Expanded(child: _buildInfoField('Care Duration', '${record.dischargeDate.difference(record.admissionDate).inHours}h ${record.dischargeDate.difference(record.admissionDate).inMinutes.remainder(60)}m')),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoField('Admission', DateFormat('dd MMM yyyy, HH:mm').format(record.admissionDate))),
                      pw.Expanded(child: _buildInfoField('Discharge', DateFormat('dd MMM yyyy, HH:mm').format(record.dischargeDate))),
                    ],
                  ),
                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    pw.Text('CLINICAL NOTES / SBAR', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(record.notes!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text('ADMINISTRATION LOG', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['TIME', 'INTERVENTION', 'STATUS / REPORT'],
              data: record.entries.map((entry) {
                return [
                  DateFormat('HH:mm').format(entry.time),
                  entry.name,
                  entry.report,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FixedColumnWidth(120),
                2: const pw.FlexColumnWidth(),
              },
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          ];
        },
      ),
    );

    final filename = 'HPR_${record.patientName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(record.dischargeDate)}.pdf';
    return await _savePdfFile(pdf, filename);
  }

  static pw.Widget _buildInfoField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Fetches history and generates a patient history PDF.
  static Future<String> savePatientHistory(Patient patient) async {
    final history = Hive.box<HPRRecord>('hpr_history')
        .values
        .where((record) => record.patientId == patient.id)
        .toList()
      ..sort((a, b) => b.dischargeDate.compareTo(a.dischargeDate));

    return await saveAuditReport(patient, history);
  }

  /// Generates and saves a PDF containing the full history (multiple HPR records) for a patient.
  static Future<String> saveAuditReport(Patient patient, List<HPRRecord> history) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ShiftChart', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('Secure Clinical Audit System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Full Audit History', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 5),
                pw.Text(
                  'CONFIDENTIAL: Full patient history containing PHI.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 2),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Text('PATIENT: ${patient.name} (Room ${patient.roomNumber})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            if (history.isEmpty)
              pw.Text('No historical records found for this patient.')
            else
              ...history.map((record) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      color: PdfColors.grey200,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Session: ${DateFormat('dd MMM yyyy').format(record.admissionDate)} - ${DateFormat('dd MMM yyyy').format(record.dischargeDate)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                          ),
                          pw.Text(
                            'Discharged: ${DateFormat('HH:mm').format(record.dischargeDate)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.TableHelper.fromTextArray(
                      headers: ['TIME', 'INTERVENTION', 'REPORT'],
                      data: record.entries.map((entry) {
                        return [
                          DateFormat('HH:mm').format(entry.time),
                          entry.name,
                          entry.report,
                        ];
                      }).toList(),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      cellStyle: const pw.TextStyle(fontSize: 8),
                      cellPadding: const pw.EdgeInsets.all(4),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(40),
                        1: const pw.FixedColumnWidth(120),
                        2: const pw.FlexColumnWidth(),
                      },
                    ),
                    pw.SizedBox(height: 20),
                  ],
                );
              }),
          ];
        },
      ),
    );

    final filename = 'Audit_History_${patient.name.replaceAll(' ', '_')}.pdf';
    return await _savePdfFile(pdf, filename);
  }

}
