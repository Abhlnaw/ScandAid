import 'dart:math' as math;
import 'dart:ui';

class Calibration {
  final Offset start;
  final Offset end;
  final double lengthCm;
  const Calibration(this.start, this.end, this.lengthCm);

  double pixelsPerCm(int width, int height) {
    final dx = (end.dx - start.dx) * width;
    final dy = (end.dy - start.dy) * height;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (!lengthCm.isFinite || lengthCm <= 0 || distance < 5) {
      throw const FormatException(
        'Mark a reference at least 5 pixels long and enter its positive length.',
      );
    }
    return distance / lengthCm;
  }

  Map<String, dynamic> toJson() => {
    'start': [start.dx, start.dy],
    'end': [end.dx, end.dy],
    'lengthCm': lengthCm,
  };
  factory Calibration.fromJson(Map<String, dynamic> j) => Calibration(
    point(j['start']),
    point(j['end']),
    (j['lengthCm'] as num).toDouble(),
  );
}

Offset point(dynamic value) =>
    Offset((value[0] as num).toDouble(), (value[1] as num).toDouble());

class Classification {
  final String label;
  final Map<String, double> scores;
  final String source;
  final String? reason;
  final bool abstained;
  const Classification({
    this.label = 'Unclassified',
    this.scores = const {},
    this.source = 'No classification model',
    this.reason,
    this.abstained = true,
  });
  Map<String, dynamic> toJson() => {
    'label': label,
    'scores': scores,
    'source': source,
    'reason': reason,
    'abstained': abstained,
  };
  factory Classification.fromJson(Map<String, dynamic> j) => Classification(
    label: j['label'] as String,
    source: j['source'] as String,
    scores: (j['scores'] as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toDouble()),
    ),
    reason: j['reason'] as String?,
    abstained: j['abstained'] as bool,
  );
}

class Scan {
  final String id;
  final String woundName;
  final DateTime createdAt;
  final String imageBase64;
  final int width;
  final int height;
  final List<Offset> outline;
  final String? maskBase64;
  final int areaPixels;
  final Rect bounds;
  final Calibration? calibration;
  final Classification classification;
  final String segmentationSource;
  final String notes;
  final double? redPixelFraction;

  const Scan({
    required this.id,
    required this.woundName,
    required this.createdAt,
    required this.imageBase64,
    required this.width,
    required this.height,
    required this.outline,
    this.maskBase64,
    required this.areaPixels,
    required this.bounds,
    this.calibration,
    required this.classification,
    required this.segmentationSource,
    this.notes = '',
    this.redPixelFraction,
  });

  double? get pixelsPerCm => calibration?.pixelsPerCm(width, height);
  double? get areaCm2 =>
      pixelsPerCm == null ? null : areaPixels / math.pow(pixelsPerCm!, 2);
  double? get lengthCm =>
      pixelsPerCm == null ? null : bounds.height / pixelsPerCm!;
  double? get widthCm =>
      pixelsPerCm == null ? null : bounds.width / pixelsPerCm!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'woundName': woundName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'imageBase64': imageBase64,
    'width': width,
    'height': height,
    'outline': outline.map((p) => [p.dx, p.dy]).toList(),
    'maskBase64': maskBase64,
    'areaPixels': areaPixels,
    'bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
    'calibration': calibration?.toJson(),
    'classification': classification.toJson(),
    'segmentationSource': segmentationSource,
    'notes': notes,
    'redPixelFraction': redPixelFraction,
  };
  factory Scan.fromJson(Map<String, dynamic> j) => Scan(
    id: j['id'] as String,
    woundName: j['woundName'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    imageBase64: j['imageBase64'] as String,
    width: j['width'] as int,
    height: j['height'] as int,
    outline: (j['outline'] as List).map(point).toList(),
    maskBase64: j['maskBase64'] as String?,
    areaPixels: j['areaPixels'] as int,
    bounds: Rect.fromLTWH(
      (j['bounds'][0] as num).toDouble(),
      (j['bounds'][1] as num).toDouble(),
      (j['bounds'][2] as num).toDouble(),
      (j['bounds'][3] as num).toDouble(),
    ),
    calibration: j['calibration'] == null
        ? null
        : Calibration.fromJson(j['calibration'] as Map<String, dynamic>),
    classification: Classification.fromJson(
      j['classification'] as Map<String, dynamic>,
    ),
    segmentationSource: j['segmentationSource'] as String,
    notes: j['notes'] as String? ?? '',
    redPixelFraction: (j['redPixelFraction'] as num?)?.toDouble(),
  );
}
