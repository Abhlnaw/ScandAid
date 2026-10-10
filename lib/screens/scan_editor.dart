import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/scan.dart';
import '../services/analysis_service.dart';
import '../services/photo_service.dart';
import '../services/scan_repository.dart';
import '../widgets/scan_photo.dart';

AnalysisResult analyzeManual((PreparedPhoto, List<Offset>) input) =>
    measureOutline(input.$1, input.$2);

class ScanEditor extends StatefulWidget {
  final PreparedPhoto photo;
  final ScanRepository repository;
  const ScanEditor({super.key, required this.photo, required this.repository});
  @override
  State<ScanEditor> createState() => _ScanEditorState();
}

class _ScanEditorState extends State<ScanEditor> {
  final name = TextEditingController(), notes = TextEditingController();
  final api = AnalysisService();
  final formKey = GlobalKey<FormState>();
  List<Offset> points = [], reference = [];
  Calibration? calibration;
  AnalysisResult? result;
  bool boxMode = false, referenceMode = false, busy = false, saving = false;
  bool get usesServer => widget.repository.serverEnabled;
  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    api.close();
    super.dispose();
  }

  void tap(Offset point) {
    if (busy || saving) return;
    if (!referenceMode && !boxMode && points.length >= 300) {
      showError(
        context,
        'Use at most 300 outline points. Undo or clear to refine the region.',
      );
      return;
    }
    setState(() {
      if (referenceMode) {
        reference = reference.length == 2 ? [point] : [...reference, point];
        calibration = null;
      } else {
        result = null;
        points = boxMode && points.length == 2 ? [point] : [...points, point];
      }
    });
  }

  Future<void> setScale() async {
    if (reference.length != 2) {
      showError(context, 'Tap both ends of a known ruler distance.');
      return;
    }
    final entered = await showDialog<double>(
      context: context,
      builder: (_) => const ScaleDialog(),
    );
    if (entered == null || !mounted) return;
    try {
      final next = Calibration(reference[0], reference[1], entered);
      next.pixelsPerCm(widget.photo.width, widget.photo.height);
      setState(() {
        calibration = next;
        referenceMode = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> analyze() async {
    if (!formKey.currentState!.validate()) return;
    if (points.length < (boxMode ? 2 : 3)) {
      showError(
        context,
        boxMode
            ? 'Tap two opposite corners around the wound.'
            : 'Tap at least three points around the wound.',
      );
      return;
    }
    setState(() {
      busy = true;
      result = null;
    });
    try {
      final next = usesServer
          ? await api.analyze(
              widget.photo,
              points,
              widget.repository.server,
              useBox: boxMode,
            )
          : await compute(analyzeManual, (widget.photo, points));
      if (mounted) setState(() => result = next);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Scan makeScan() => Scan(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    woundName: name.text.trim(),
    createdAt: DateTime.now(),
    imageBase64: base64Encode(widget.photo.bytes),
    width: widget.photo.width,
    height: widget.photo.height,
    outline: List.of(points),
    maskBase64: result!.maskBase64,
    areaPixels: result!.areaPixels,
    bounds: result!.bounds,
    calibration: calibration,
    classification: result!.classification,
    segmentationSource: result!.source,
    notes: notes.text.trim(),
    redPixelFraction: result!.redPixelFraction,
  );
  Future<void> save() async {
    if (!formKey.currentState!.validate() || result == null) return;
    setState(() => saving = true);
    try {
      await widget.repository.saveScan(makeScan());
      if (!mounted) return;
      setState(() => saving = false);
      // Let PopScope observe the completed save before closing this route.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void undo() => setState(() {
    if (referenceMode) {
      reference = reference.take(reference.length - 1).toList();
      calibration = null;
    } else {
      points = points.take(points.length - 1).toList();
      result = null;
    }
  });
  @override
  Widget build(BuildContext context) {
    final names = widget.repository.scans.map((s) => s.woundName).toSet();
    return PopScope(
      canPop: !busy && !saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('New entry')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  const Text(
                    'Mark what you want to track.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: name,
                    enabled: !busy && !saving,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Wound name',
                      hintText: 'e.g. Left knee',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Give this wound a name to group follow-ups.'
                        : null,
                  ),
                  if (names.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: names
                          .take(10)
                          .map(
                            (n) => ActionChip(
                              label: Text(n),
                              onPressed: busy || saving
                                  ? null
                                  : () => name.text = n,
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  if (usesServer)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Manual outline'),
                          icon: Icon(Icons.gesture),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Assisted box'),
                          icon: Icon(Icons.crop_free),
                        ),
                      ],
                      selected: {boxMode},
                      onSelectionChanged: busy || saving
                          ? null
                          : (v) => setState(() {
                              boxMode = v.first;
                              points = [];
                              result = null;
                              referenceMode = false;
                            }),
                    ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      referenceMode
                          ? 'Tap the two ends of a known distance on your ruler, then set its length.'
                          : boxMode
                          ? 'Tap two opposite corners to enclose the wound. The server will refine the region. Review the resulting mask before saving.'
                          : 'Tap points in order around the wound perimeter. The final point connects to the first. Review the outline before saving.',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScanPhoto(
                    bytes: widget.photo.bytes,
                    width: widget.photo.width,
                    height: widget.photo.height,
                    points: points,
                    mask: result?.maskBase64,
                    box: boxMode,
                    calibration: calibration,
                    reference: reference,
                    onTap: busy || saving ? null : tap,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed:
                            busy ||
                                saving ||
                                (referenceMode
                                    ? reference.isEmpty
                                    : points.isEmpty)
                            ? null
                            : undo,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo point'),
                      ),
                      TextButton.icon(
                        onPressed: busy || saving
                            ? null
                            : () => setState(() {
                                if (referenceMode) {
                                  reference = [];
                                  calibration = null;
                                } else {
                                  points = [];
                                  result = null;
                                }
                              }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Clear'),
                      ),
                      TextButton.icon(
                        onPressed: busy || saving
                            ? null
                            : () => setState(
                                () => referenceMode = !referenceMode,
                              ),
                        icon: Icon(
                          referenceMode ? Icons.gesture : Icons.straighten,
                        ),
                        label: Text(
                          referenceMode
                              ? 'Back to wound'
                              : 'Mark scale reference',
                        ),
                      ),
                      if (referenceMode && reference.length == 2)
                        FilledButton.tonal(
                          onPressed: setScale,
                          child: const Text('Set reference length'),
                        ),
                    ],
                  ),
                  if (calibration != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Scale set: ${calibration!.lengthCm} cm between the yellow points.',
                        style: const TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Optional: mark a ruler reference for centimeters. Otherwise area is shown in pixels.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    enabled: !busy && !saving,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'What changed since your last photo?',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: busy || saving || referenceMode ? null : analyze,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(
                      busy
                          ? 'Analyzing…'
                          : usesServer
                          ? 'Analyze selected region'
                          : 'Measure outline',
                    ),
                  ),
                  if (usesServer)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Sends this prepared photo to your configured server. AI predictions are experimental.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  if (result != null) ...[
                    const SizedBox(height: 24),
                    ResultsCard(scan: makeScan()),
                    const SizedBox(height: 16),
                    const Text(
                      'Check the highlighted region. Refine your selection and analyze again if it includes surrounding skin or misses part of the wound.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving || busy ? null : save,
                      icon: const Icon(Icons.check),
                      label: Text(saving ? 'Saving…' : 'Save reviewed entry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScaleDialog extends StatefulWidget {
  const ScaleDialog({super.key});
  @override
  State<ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends State<ScaleDialog> {
  final controller = TextEditingController(text: '1');
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reference length'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Enter the distance between the marked points. The ruler must be beside the wound in the same plane.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Length in centimeters',
            errorText: error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = double.tryParse(controller.text.replaceAll(',', '.'));
          if (value == null || !value.isFinite || value <= 0 || value > 100) {
            setState(
              () => error = 'Enter a length greater than 0 and at most 100 cm.',
            );
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Set scale'),
      ),
    ],
  );
}
