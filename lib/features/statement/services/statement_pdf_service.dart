
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/statement_provider.dart';

class StatementPdfService {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final DateFormat _dateFormat = DateFormat(
    'dd MMM yyyy',
    'id_ID',
  );

  static Future<void> export(AccountStatement statement) async {
    final pdf = pw.Document();

    final entries = <_PdfEntry>[];

    for (final transaction in statement.transactions) {
      entries.add(
        _PdfEntry(
          date: transaction.transactionDate,
          description: transaction.description?.trim().isNotEmpty == true
              ? transaction.description!.trim()
              : transaction.isIncome
                  ? 'Pemasukan'
                  : 'Pengeluaran',
          type: transaction.isIncome ? 'Pemasukan' : 'Pengeluaran',
          debit: transaction.isExpense ? transaction.amount : 0,
          credit: transaction.isIncome ? transaction.amount : 0,
        ),
      );
    }

    for (final transfer in statement.transfers) {
      final isIncoming = transfer.toAccountId == statement.account.id;

      entries.add(
        _PdfEntry(
          date: transfer.transferDate,
          description: transfer.description?.trim().isNotEmpty == true
              ? transfer.description!.trim()
              : isIncoming
                  ? 'Transfer masuk'
                  : 'Transfer keluar',
          type: isIncoming ? 'Transfer masuk' : 'Transfer keluar',
          debit: isIncoming ? 0 : transfer.amount,
          credit: isIncoming ? transfer.amount : 0,
        ),
      );
    }

    entries.sort((a, b) => a.date.compareTo(b.date));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColors.blueGrey300,
                width: 1,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'FINTRACK',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.Text(
                'E-STATEMENT',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'FinTrack - Laporan Mutasi Rekening',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Text(
            'Laporan Mutasi Rekening',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Periode ${_dateFormat.format(statement.startDate)} - '
            '${_dateFormat.format(statement.endDate)}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 20),

          // Informasi rekening
          _sectionTitle('Informasi Rekening'),
          pw.SizedBox(height: 8),
          _infoRow('Nama rekening', statement.account.name),
          _infoRow('Jenis rekening', statement.account.accountType),
          if (statement.account.bankName?.isNotEmpty == true)
            _infoRow('Bank', statement.account.bankName!),
          if (statement.account.accountNumber?.isNotEmpty == true)
            _infoRow('Nomor rekening', statement.account.accountNumber!),

          pw.SizedBox(height: 20),

          // Saldo awal dan akhir
          _sectionTitle('Ringkasan Saldo'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                _amountRow(
                  'Saldo awal',
                  statement.openingBalance,
                ),
                pw.SizedBox(height: 8),
                _amountRow(
                  'Saldo akhir',
                  statement.closingBalance,
                  bold: true,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Ringkasan mutasi
          _sectionTitle('Ringkasan Mutasi'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              _summaryRow('Pemasukan', statement.totalIncome),
              _summaryRow('Pengeluaran', statement.totalExpense),
              _summaryRow('Transfer masuk', statement.transferIn),
              _summaryRow('Transfer keluar', statement.transferOut),
            ],
          ),

          pw.SizedBox(height: 22),

          // Riwayat transaksi
          _sectionTitle('Riwayat Mutasi'),
          pw.SizedBox(height: 10),

          if (entries.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                'Tidak ada mutasi pada periode ini.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Tanggal',
                'Keterangan',
                'Jenis',
                'Debit',
                'Kredit',
              ],
              data: entries.map((entry) {
                return [
                  _dateFormat.format(entry.date),
                  entry.description,
                  entry.type,
                  entry.debit > 0 ? _currency.format(entry.debit) : '-',
                  entry.credit > 0 ? _currency.format(entry.credit) : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(1.8),
              },
            ),

          pw.SizedBox(height: 20),
          pw.Text(
            'Dokumen ini dibuat secara otomatis melalui aplikasi FinTrack.',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    final accountName = statement.account.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final filename =
        'FinTrack_EStatement_${accountName}_'
        '${DateFormat('yyyyMMdd').format(statement.startDate)}_'
        '${DateFormat('yyyyMMdd').format(statement.endDate)}.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue800,
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 115,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(
            ': $value',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _amountRow(
    String label,
    double amount, {
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _currency.format(amount),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
      ],
    );
  }

  static pw.TableRow _summaryRow(String label, double amount) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            _currency.format(amount),
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }
}

class _PdfEntry {
  final DateTime date;
  final String description;
  final String type;
  final double debit;
  final double credit;

  const _PdfEntry({
    required this.date,
    required this.description,
    required this.type,
    required this.debit,
    required this.credit,
  });
}
