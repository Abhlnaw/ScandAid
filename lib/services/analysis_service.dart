import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/scan.dart';
import 'photo_service.dart';

class AnalysisResult {
  final int areaPixels;
  final Rect bounds;
  final String? maskBase64;
  final String source;
  final Classification classification;
  final double? redPixelFraction;
  const AnalysisResult({
    required this.areaPixels,
    required this.bounds,
    this.maskBase64,
    required this.source,
    required this.classification,
    this.redPixelFraction,
  });
}

bool insidePolygon(double x, double y, List<Offset> vertices) {
  var inside = false;
  for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
    final a = vertices[i], b = vertices[j];
    if ((a.dy > y) != (b.dy > y) &&
        x < (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

bool hasCrossings(List<Offset> vertices) {
  double cross(Offset a, Offset b, Offset c) =>
      (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
  bool touches(Offset a, Offset b, Offset p) =>
      cross(a, b, p).abs() < 1e-9 &&
      p.dx >= math.min(a.dx, b.dx) &&
      p.dx <= math.max(a.dx, b.dx) &&
      p.dy >= math.min(a.dy, b.dy) &&
      p.dy <= math.max(a.dy, b.dy);
  for (var i = 0; i < vertices.length; i++) {
    final a = vertices[i], b = vertices[(i + 1) % vertices.length];
    if ((a - b).distance < 1e-9) return true;
    for (var j = i + 1; j < vertices.length; j++) {
      if (j == i + 1 || (i == 0 && j == vertices.length - 1)) continue;
      final c = vertices[j], d = vertices[(j + 1) % vertices.length];
      if ((cross(a, b, c) * cross(a, b, d) < 0 &&
              cross(c, d, a) * cross(c, d, b) < 0) ||
          touches(a, b, c) ||
          touches(a, b, d) ||
          touches(c, d, a) ||
          touches(c, d, b)) {
        return true;
      }
    }
  }
  return false;
}

AnalysisResult measureOutline(PreparedPhoto photo, List<Offset> outline) {
  if (outline.length < 3 || outline.length > 300) {
    throw const FormatException('Use between three and 300 outline points.');
  }
  if (outline.any(
    (p) =>
        !p.dx.isFinite ||
        !p.dy.isFinite ||
        p.dx < 0 ||
        p.dx > 1 ||
        p.dy < 0 ||
        p.dy > 1,
  )) {
    throw const FormatException('The outline must stay inside the photo.');
  }
  if (hasCrossings(outline)) {
    throw const FormatException(
      'The outline crosses or repeats itself. Trace the perimeter in order.',
    );
  }
  final vertices = outline
      .map((p) => Offset(p.dx * photo.width, p.dy * photo.height))
      .toList();
  final minX = vertices
      .map((p) => p.dx.floor())
      .reduce(math.min)
      .clamp(0, photo.width - 1);
  final maxX = vertices
      .map((p) => p.dx.ceil())
      .reduce(math.max)
      .clamp(0, photo.width);
  final minY = vertices
      .map((p) => p.dy.floor())
      .reduce(math.min)
      .clamp(0, photo.height - 1);
  final maxY = vertices
      .map((p) => p.dy.ceil())
      .reduce(math.max)
      .clamp(0, photo.height);
  var area = 0,
      red = 0,
      left = photo.width,
      right = 0,
      top = photo.height,
      bottom = 0;
  final image = img.decodeJpg(photo.bytes)!;
  for (var y = minY; y < maxY; y++) {
    for (var x = minX; x < maxX; x++) {
      if (!insidePolygon(x + .5, y + .5, vertices)) continue;
      area++;
      left = math.min(left, x);
      right = math.max(right, x + 1);
      top = math.min(top, y);
      bottom = math.max(bottom, y + 1);
      final p = image.getPixel(x, y);
      if (p.r > p.g * 1.25 && p.r > p.b * 1.25 && p.r > 60) red++;
    }
  }
  if (area < 9) {
    throw const FormatException(
      'The outline is too small or crosses itself. Draw a clear perimeter.',
    );
  }
  return AnalysisResult(
    areaPixels: area,
    bounds: Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    ),
    source: 'Manual outline',
    classification: const Classification(
      reason:
          'Connect an inference server in Settings to enable model predictions.',
    ),
    redPixelFraction: red / area,
  );
}

class AnalysisService {
  final http.Client client;
  AnalysisService({http.Client? client}) : client = client ?? http.Client();
  void close() => client.close();

  static Uri endpoint(String base, String path) {
    final uri = Uri.tryParse(base.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path != '' && uri.path != '/')) {
      throw const FormatException(
        'Enter a server origin, for example http://127.0.0.1:8000.',
      );
    }
    final octets = uri.host.split('.').map(int.tryParse).toList();
    final privateIp =
        octets.length == 4 &&
        octets.every((v) => v != null && v >= 0 && v <= 255) &&
        (octets[0] == 10 ||
            (octets[0] == 192 && octets[1] == 168) ||
            (octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31));
    final local =
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1' ||
        uri.host == '10.0.2.2' ||
        privateIp;
    if (uri.scheme != 'https' && !local) {
      throw const FormatException(
        'Use HTTPS for servers outside your local network.',
      );
    }
    return uri.replace(path: path);
  }

  Future<Map<String, dynamic>> health(String base) async {
    final response = await client
        .get(endpoint(base, '/health'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Server returned ${response.statusCode}.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<AnalysisResult> analyze(
    PreparedPhoto photo,
    List<Offset> outline,
    String base, {
    required bool useBox,
  }) async {
    if (outline.length < (useBox ? 2 : 3)) {
      throw const FormatException('Mark the wound region first.');
    }
    final xs = outline.map((p) => p.dx), ys = outline.map((p) => p.dy);
    final box = [
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    ];
    final request = http.MultipartRequest('POST', endpoint(base, '/analyze'))
      ..fields['box'] = jsonEncode(box)
      ..fields['outline'] = useBox
          ? '[]'
          : jsonEncode(outline.map((p) => [p.dx, p.dy]).toList())
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          photo.bytes,
          filename: 'scan.jpg',
        ),
      );
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 120)),
    ).timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) {
      String message = 'Analysis failed (${response.statusCode}).';
      try {
        message = (jsonDecode(response.body) as Map)['detail'].toString();
      } catch (_) {
        /* Retain status. */
      }
      throw StateError(message);
    }
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final mask = j['segmentation'] as Map<String, dynamic>;
    final data = base64Decode(mask['maskPng'] as String);
    final decoded = img.decodePng(data);
    if (decoded == null ||
        decoded.width != photo.width ||
        decoded.height != photo.height) {
      throw const FormatException(
        'The server returned a mask with incorrect dimensions.',
      );
    }
    // Derive measurements from returned pixels; never trust a reported box area.
    var area = 0, left = photo.width, top = photo.height, right = 0, bottom = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        if (decoded.getPixel(x, y).r < 128) continue;
        area++;
        left = math.min(left, x);
        top = math.min(top, y);
        right = math.max(right, x + 1);
        bottom = math.max(bottom, y + 1);
      }
    }
    if (area < 9) {
      throw const FormatException(
        'No usable region was found. Refine the selection and try again.',
      );
    }
    final fraction = (j['redPixelFraction'] as num?)?.toDouble();
    if (fraction != null &&
        (!fraction.isFinite || fraction < 0 || fraction > 1)) {
      throw const FormatException('Invalid visual feature values from server.');
    }
    return AnalysisResult(
      areaPixels: area,
      bounds: Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        right.toDouble(),
        bottom.toDouble(),
      ),
      maskBase64: base64Encode(Uint8List.fromList(data)),
      source: mask['source'] as String,
      classification: Classification.fromJson(
        j['classification'] as Map<String, dynamic>,
      ),
      redPixelFraction: fraction,
    );
  }
}
