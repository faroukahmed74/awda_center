import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/app_logo.dart';
import '../../core/date_format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';
import '../../models/user_model.dart';
import '../../widgets/medical/medical_rich_text_html.dart';
import 'patient_report_pdf.dart';

String _xmlEscape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _plainDiagnosis(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  final raw = value.trim();
  if (MedicalRichTextHtml.isLikelyHtml(raw) ||
      MedicalRichTextHtml.isDeltaJson(raw)) {
    final plain = MedicalRichTextHtml.htmlToPlainText(raw).trim();
    return plain.isEmpty ? '—' : plain;
  }
  return raw;
}

String _wText(String text, {bool bold = false, String? colorHex, int sz = 20}) {
  final escaped = _xmlEscape(text);
  final color = colorHex == null ? '' : '<w:color w:val="$colorHex"/>';
  final b = bold ? '<w:b/>' : '';
  return '<w:r><w:rPr>$b$color<w:sz w:val="$sz"/><w:szCs w:val="$sz"/></w:rPr>'
      '<w:t xml:space="preserve">$escaped</w:t></w:r>';
}

String _wParagraph(
  String text, {
  bool bold = false,
  String align = 'left',
  String? colorHex,
  int spaceAfter = 120,
  int sz = 20,
}) {
  return '<w:p>'
      '<w:pPr><w:jc w:val="$align"/><w:spacing w:after="$spaceAfter"/></w:pPr>'
      '${_wText(text, bold: bold, colorHex: colorHex, sz: sz)}'
      '</w:p>';
}

String _wTc(String text, {bool bold = false, String? fill, String? colorHex}) {
  final shd = fill == null
      ? ''
      : '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>';
  return '<w:tc>'
      '<w:tcPr><w:tcW w:w="0" w:type="auto"/>$shd'
      '<w:tcBorders>'
      '<w:top w:val="single" w:sz="4" w:color="000000"/>'
      '<w:left w:val="single" w:sz="4" w:color="000000"/>'
      '<w:bottom w:val="single" w:sz="4" w:color="000000"/>'
      '<w:right w:val="single" w:sz="4" w:color="000000"/>'
      '</w:tcBorders></w:tcPr>'
      '<w:p><w:pPr><w:spacing w:before="40" w:after="40"/></w:pPr>'
      '${_wText(text, bold: bold, colorHex: colorHex)}'
      '</w:p></w:tc>';
}

String _tblOpen() =>
    '<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/>'
    '<w:tblBorders>'
    '<w:top w:val="single" w:sz="8" w:color="000000"/>'
    '<w:left w:val="single" w:sz="8" w:color="000000"/>'
    '<w:bottom w:val="single" w:sz="8" w:color="000000"/>'
    '<w:right w:val="single" w:sz="8" w:color="000000"/>'
    '<w:insideH w:val="single" w:sz="8" w:color="000000"/>'
    '<w:insideV w:val="single" w:sz="8" w:color="000000"/>'
    '</w:tblBorders></w:tblPr>';

/// Centered inline PNG (~1.5" × 1.5") referenced as rIdLogo.
String _centeredLogoParagraph({int cxEmu = 1371600, int cyEmu = 1371600}) {
  return '''
<w:p>
  <w:pPr><w:jc w:val="center"/><w:spacing w:after="80"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0"
        xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
        xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <wp:extent cx="$cxEmu" cy="$cyEmu"/>
        <wp:docPr id="1" name="CenterLogo"/>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="logo.png"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="rIdLogo"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="$cxEmu" cy="$cyEmu"/>
                </a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>''';
}

Future<Uint8List?> _loadReportLogoBytes() async {
  const candidates = [
    'assets/CenterLogo.png',
    kAppLogoLightAsset,
    'assets/AppLogo.png',
  ];
  for (final path in candidates) {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      // try next
    }
  }
  return null;
}

/// Builds a .docx with centered logo + center name and the compact report layout.
/// [sessionRows] should already be oldest→newest.
Future<Uint8List> buildPatientReportDocx({
  required UserModel user,
  required PatientProfileModel? profile,
  required List<PatientReportSessionRow> sessionRows,
  required AppLocalizations l10n,
  required String centerName,
  String currency = 'EGP',
  List<PatientReportPackageProgress> packageProgress = const [],
}) async {
  final isArabic = l10n.isArabic;
  final nf = NumberFormat.currency(symbol: '', decimalDigits: 2);
  final patientName =
      user.displayName.trim().isEmpty ? '—' : user.displayName.trim();
  final reportDate = AppDateFormat.shortDate.format(DateTime.now());
  final diagnosis = _plainDiagnosis(profile?.diagnosis);
  final paymentTotal = patientReportPaymentTotal(sessionRows);
  final totalLabel =
      '${nf.format(paymentTotal).trim()} ${currency.trim().isEmpty ? 'EGP' : currency.trim()}';
  final sessionsTitle = '${l10n.sessions} & ${l10n.amountPaid}';
  final logoBytes = await _loadReportLogoBytes();
  final hasLogo = logoBytes != null && logoBytes.isNotEmpty;

  final body = StringBuffer();
  if (hasLogo) {
    body.write(_centeredLogoParagraph());
  }
  body
    ..write(
      _wParagraph(
        centerName,
        bold: true,
        align: 'center',
        spaceAfter: 240,
        sz: 32,
      ),
    )
    ..write(_tblOpen())
    ..write(
      '<w:tr>${_wTc(l10n.name.toUpperCase(), bold: true)}${_wTc(patientName)}'
      '${_wTc(l10n.date.toUpperCase(), bold: true)}${_wTc(reportDate)}</w:tr>',
    )
    ..write('</w:tbl>')
    ..write(_tblOpen())
    ..write(
      '<w:tr>${_wTc(l10n.diagnosis.toUpperCase(), bold: true)}'
      '${_wTc(diagnosis)}</w:tr>',
    )
    ..write('</w:tbl>')
    ..write(_wParagraph('', spaceAfter: 80))
    ..write(_wParagraph(sessionsTitle, bold: true, spaceAfter: 120))
    ..write(_tblOpen())
    ..write(
      '<w:tr>'
      '${_wTc(l10n.date, bold: true, fill: 'E3F2FD', colorHex: '0D47A1')}'
      '${_wTc(l10n.time, bold: true, fill: 'E3F2FD', colorHex: '0D47A1')}'
      '${_wTc(l10n.services, bold: true, fill: 'E3F2FD', colorHex: '0D47A1')}'
      '${_wTc(l10n.status, bold: true, fill: 'E3F2FD', colorHex: '0D47A1')}'
      '${_wTc(l10n.sessionPayment, bold: true, fill: 'E3F2FD', colorHex: '0D47A1')}'
      '</w:tr>',
    );

  if (sessionRows.isEmpty) {
    body.write(
      '<w:tr>${_wTc(l10n.noData)}${_wTc('')}${_wTc('')}${_wTc('')}${_wTc('')}</w:tr>',
    );
  } else {
    for (final r in sessionRows) {
      final service = (r.service != null && r.service!.trim().isNotEmpty)
          ? r.service!.trim()
          : '—';
      final status = (r.statusLabel != null && r.statusLabel!.trim().isNotEmpty)
          ? r.statusLabel!.trim()
          : '—';
      final payment = patientReportSessionPaymentLabel(r, l10n, nf);
      final dateStr = AppDateFormat.shortDateWithWeekday(
        r.date,
        locale: isArabic ? 'ar' : 'en',
      );
      body.write(
        '<w:tr>'
        '${_wTc(dateStr)}'
        '${_wTc('${r.startTime}–${r.endTime}')}'
        '${_wTc(service)}'
        '${_wTc(status)}'
        '${_wTc(payment)}'
        '</w:tr>',
      );
    }
  }

  body
    ..write(
      '<w:tr>'
      '${_wTc(l10n.total, bold: true, colorHex: '1565C0')}'
      '${_wTc('')}${_wTc('')}${_wTc('')}'
      '${_wTc(totalLabel, bold: true)}'
      '</w:tr>',
    )
    ..write('</w:tbl>');

  if (packageProgress.isNotEmpty) {
    body
      ..write(_wParagraph('', spaceAfter: 80))
      ..write(_wParagraph(l10n.packages, bold: true, spaceAfter: 80));
    for (final p in packageProgress) {
      final name = p.name.trim().isEmpty ? '—' : p.name.trim();
      body.write(
        _wParagraph(
          '$name  —  ${p.completed} / ${p.total} ${l10n.sessions}',
          spaceAfter: 60,
        ),
      );
    }
  }

  final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    ${body.toString()}
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/>
    </w:sectPr>
  </w:body>
</w:document>''';

  final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

  final rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  final docRels = hasLogo
      ? '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdLogo" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/logo.png"/>
</Relationships>'''
      : '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

  final archive = Archive();
  void addXml(String name, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addXml('[Content_Types].xml', contentTypes);
  addXml('_rels/.rels', rels);
  addXml('word/document.xml', documentXml);
  addXml('word/_rels/document.xml.rels', docRels);
  if (hasLogo) {
    archive.addFile(
      ArchiveFile('word/media/logo.png', logoBytes.length, logoBytes),
    );
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('Failed to encode patient report docx');
  }
  return Uint8List.fromList(encoded);
}
