import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/classification_result.dart';
import 'package:ecosort/screens/gallery_result_screen.dart';
import 'package:ecosort/theme/app_theme.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import '../fakes.dart';

class FakeImagePickerPlatform extends ImagePickerPlatform {
  XFile? nextFile;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return nextFile;
  }

  @override
  Future<LostDataResponse> getLostData() async {
    return LostDataResponse.empty();
  }
}

void main() {
  late Uint8List testImageBytes;
  late String tempImagePath;
  late ImagePickerPlatform originalPickerPlatform;

  setUpAll(() {
    final image = img.Image(width: 100, height: 100);
    testImageBytes = Uint8List.fromList(img.encodePng(image));
  });

  setUp(() {
    final tempFile = File(
      '${Directory.systemTemp.createTempSync('ecosort_test').path}${Platform.pathSeparator}picked.png',
    )..writeAsBytesSync(testImageBytes);
    tempImagePath = tempFile.path;

    originalPickerPlatform = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = FakeImagePickerPlatform()
      ..nextFile = XFile(tempImagePath);
  });

  tearDown(() {
    ImagePickerPlatform.instance = originalPickerPlatform;
  });

  Future<void> pumpScreen(WidgetTester tester, FakeClassifier classifier) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: GalleryResultScreen(
          initialImageBytes: testImageBytes,
          initialClassification: ClassificationResult.fromIndex(0, 0.87),
          classifier: classifier,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows classification result and buttons', (tester) async {
    await pumpScreen(tester, FakeClassifier());

    expect(find.text('Hasil Klasifikasi Foto'), findsOneWidget);
    expect(find.text('Hasil Klasifikasi'), findsOneWidget);
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Skor model: 87%'), findsOneWidget);
    expect(find.text('Pilih Foto Lain'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
  });

  testWidgets('failed re-pick keeps the previous photo and result', (
    tester,
  ) async {
    final classifier = FakeClassifier()..classifyThrows = StateError('boom');
    await pumpScreen(tester, classifier);

    await tester.ensureVisible(find.text('Pilih Foto Lain'));
    await tester.pumpAndSettle();
    // Tap and complete the chain inside runAsync: the flow does real file
    // IO plus Isolate.run, which fake async cannot drive.
    await tester.runAsync(() async {
      await tester.tap(find.text('Pilih Foto Lain'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal memproses gambar'), findsOneWidget);
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Skor model: 87%'), findsOneWidget);
  });

  testWidgets('successful re-pick updates photo and result together', (
    tester,
  ) async {
    final classifier = FakeClassifier()
      ..classifyThrows = null
      ..nextResult = ClassificationResult.fromIndex(4, 0.42);
    await pumpScreen(tester, classifier);

    await tester.ensureVisible(find.text('Pilih Foto Lain'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Pilih Foto Lain'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.text('Plastik'), findsOneWidget);
    expect(find.text('Skor model: 42%'), findsOneWidget);
    expect(find.textContaining('Gagal'), findsNothing);
  });
}