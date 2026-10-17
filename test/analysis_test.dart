import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:scandaid/models/scan.dart';
import 'package:scandaid/services/analysis_service.dart';
import 'package:scandaid/services/photo_service.dart';
import 'support.dart';

void main() {
  test(
    'photo preparation applies orientation and removes EXIF identifiers',
    () {
      final image = img.Image(width: 100, height: 80);
      img.fill(image, color: img.ColorRgb8(180, 120, 95));
      image.exif.imageIfd['ImageDescription'] = 'private camera note';
      image.exif.imageIfd['Orientation'] = 6;
      image.exif.gpsIfd[1] = img.IfdValueAscii('N');
      final source = img.encodeJpg(image);
      expect(img.decodeJpg(source)!.exif.isEmpty, isFalse);
      final prepared = preparePhoto(source);
      expect(prepared.width, 80);
      expect(prepared.height, 100);
      expect(img.decodeJpg(prepared.bytes)!.exif.isEmpty, isTrue);
    },
  );
  test(
    'manual mask counts pixel centers rather than a bounding rectangle guess',
    () {
      final result = measureOutline(testPhoto(), rectangle);
      expect(result.areaPixels, 2000);
      expect(result.bounds, const Rect.fromLTWH(25, 20, 50, 40));
      final triangle = measureOutline(testPhoto(), [
        const Offset(.2, .2),
        const Offset(.8, .2),
        const Offset(.2, .8),
      ]);
      expect(
        triangle.areaPixels,
        lessThan(triangle.bounds.width * triangle.bounds.height * .55),
      );
      expect(result.classification.abstained, isTrue);
      expect(result.classification.scores, isEmpty);
    },
  );
  test(
    'centimeters require a per-image reference and scale quadratically for area',
    () {
      final scan = testScan();
      expect(scan.areaCm2, 20);
      expect(scan.widthCm, 5);
      expect(scan.lengthCm, 4);
      final json = scan.toJson()..['calibration'] = null;
      expect(Scan.fromJson(json).areaCm2, isNull);
      expect(
        () =>
            const Calibration(Offset.zero, Offset.zero, 1).pixelsPerCm(100, 80),
        throwsFormatException,
      );
      expect(
        () => const Calibration(
          Offset.zero,
          Offset(1, 1),
          0,
        ).pixelsPerCm(100, 80),
        throwsFormatException,
      );
    },
  );
  test('invalid, tiny, or unbounded outlines are rejected', () {
    expect(() => measureOutline(testPhoto(), []), throwsFormatException);
    expect(
      () => measureOutline(testPhoto(), [
        const Offset(.1, .1),
        const Offset(.8, .8),
        const Offset(.8, .1),
        const Offset(.1, .8),
      ]),
      throwsFormatException,
    );
    expect(
      () => measureOutline(testPhoto(), [
        const Offset(-1, 0),
        const Offset(1, 0),
        const Offset(1, 1),
      ]),
      throwsFormatException,
    );
    expect(
      () => measureOutline(testPhoto(), [
        Offset.zero,
        const Offset(.01, 0),
        const Offset(0, .01),
      ]),
      throwsFormatException,
    );
  });
  test(
    'photos are resized with aspect ratio intact and invalid files fail',
    () {
      final prepared = testPhoto(width: 1800, height: 900);
      expect(prepared.width, 1600);
      expect(prepared.height, 800);
      expect(img.decodeJpg(prepared.bytes), isNotNull);
      expect(
        () => preparePhoto(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    },
  );
  test('API settings reject credentials and insecure public origins', () {
    expect(
      AnalysisService.endpoint('http://127.0.0.1:8000', '/analyze').path,
      '/analyze',
    );
    expect(
      AnalysisService.endpoint('https://example.org', '/health').scheme,
      'https',
    );
    for (final origin in [
      'http://example.org',
      'http://10.example.org',
      'https://u:p@example.org',
      'file:///tmp',
      'https://example.org/path',
      'https://example.org?key=secret',
    ]) {
      expect(
        () => AnalysisService.endpoint(origin, '/health'),
        throwsFormatException,
      );
    }
  });
  test(
    'API measurements are recomputed from the mask instead of trusting server area',
    () async {
      final mask = img.Image(width: 100, height: 80);
      img.fillRect(
        mask,
        x1: 25,
        y1: 20,
        x2: 74,
        y2: 59,
        color: img.ColorRgb8(255, 255, 255),
      );
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'segmentation': {
              'areaPixels': 999999,
              'maskPng': base64Encode(img.encodePng(mask)),
              'source': 'Test mask',
            },
            'classification': const Classification().toJson(),
            'redPixelFraction': .2,
          }),
          200,
        ),
      );
      final api = AnalysisService(client: client);
      final result = await api.analyze(
        testPhoto(),
        rectangle,
        'http://localhost:8000',
        useBox: false,
      );
      expect(result.areaPixels, 2000);
      expect(result.bounds, const Rect.fromLTWH(25, 20, 50, 40));
      api.close();
    },
  );
  test('server errors and mismatched masks are surfaced', () async {
    final errorApi = AnalysisService(
      client: MockClient(
        (r) async => http.Response('{"detail":"Server busy"}', 429),
      ),
    );
    await expectLater(
      errorApi.analyze(
        testPhoto(),
        rectangle,
        'http://localhost:8000',
        useBox: false,
      ),
      throwsStateError,
    );
    errorApi.close();
    final api = AnalysisService(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'segmentation': {
              'maskPng': base64Encode(
                img.encodePng(img.Image(width: 1, height: 1)),
              ),
            },
          }),
          200,
        ),
      ),
    );
    await expectLater(
      api.analyze(
        testPhoto(),
        rectangle,
        'http://localhost:8000',
        useBox: false,
      ),
      throwsFormatException,
    );
    api.close();
  });
}
