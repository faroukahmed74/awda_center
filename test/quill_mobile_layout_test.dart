import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:awda_center/widgets/medical/medical_rich_text_field.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  testWidgets(
    'MedicalRichTextField custom toolbar buttons do not ErrorWidget on iOS',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              surface: Color(0xFF1E293B),
              onSurface: Color(0xFFF1F5F9),
            ),
          ),
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
          ],
          home: Scaffold(
            body: AlertDialog(
              content: SizedBox(
                width: 390,
                height: 600,
                child: SingleChildScrollView(
                  child: MedicalRichTextField(
                    label: 'Chief complaint / Reason for referral',
                    onLabelColorChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      debugDefaultTargetPlatformOverride = null;

      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(QuillEditor), findsOneWidget);
      expect(find.byIcon(Icons.format_paint), findsOneWidget);
    },
  );
}
