import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/screens/home_screen.dart';
import 'package:ecosort/theme/app_theme.dart';
import '../fakes.dart';

void main() {
  testWidgets('HomeScreen renders title, six classes, and action buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: HomeScreen(classifier: FakeClassifier()),
      ),
    );

    expect(find.text('EcoSort'), findsOneWidget);
    expect(find.text('Kategori Sampah Didukung'), findsOneWidget);
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Kaca'), findsOneWidget);
    expect(find.text('Logam'), findsOneWidget);
    expect(find.text('Kertas'), findsOneWidget);
    expect(find.text('Plastik'), findsOneWidget);
    expect(find.text('Sampah lainnya'), findsOneWidget);
    expect(find.text('Mulai Kamera'), findsOneWidget);
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
  });

  testWidgets('HomeScreen pushes CameraScreen on camera tap', (tester) async {
    // Provide an empty camera list so the pushed screen settles on its
    // error state instead of calling the platform channel.
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (call) async {
        if (call.method == 'availableCameras') {
          return <Map<String, Object>>[];
        }
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: HomeScreen(classifier: FakeClassifier()),
      ),
    );

    await tester.tap(find.text('Mulai Kamera'));
    await tester.pumpAndSettle();

    expect(find.text('Klasifikasi Langsung'), findsOneWidget);
  });
}