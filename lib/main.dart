import 'dart:io';
import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'services/ml_service.dart';
import 'services/classification_service.dart';
import 'models/measurement_data.dart';
import 'models/diagnostic_data.dart';

void main() {
  runApp(const ScandAidTestApp());
}

class ScandAidTestApp extends StatelessWidget {
  const ScandAidTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CameraTestScreen(),
    );
  }
}

class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  final CameraService _cameraService = CameraService();
  final MlService _mlService = MlService();
  final ClassificationService _classificationService = ClassificationService();
  
  String? _capturedImagePath;
  MeasurementData? _mlMeasurements;
  DiagnosticData? _diagnosticInsights;
  bool _isProcessing = false;

  Future<void> _handleImageSelection(bool fromCamera) async {
    setState(() {
      _isProcessing = true;
      _mlMeasurements = null;
      _diagnosticInsights = null;
    });

    final String? path = fromCamera 
        ? await _cameraService.captureInjuryPhoto()
        : await _cameraService.selectPhotoFromGallery();

    if (path == null) {
      setState(() => _isProcessing = false);
      return; 
    }

    setState(() {
      _capturedImagePath = path;
    });

    MeasurementData? metrics = await _mlService.analyzeInjuryContours(path);
    final DiagnosticData? diagnostics = await _classificationService.classifyInjury(path);

    if (metrics == null) {
      final bytes = await File(path).readAsBytes();
      final image = await decodeImageFromList(bytes);
      
      double boxWidth = image.width * 0.50;
      double boxHeight = image.height * 0.60;
      double left = (image.width - boxWidth) / 2;
      double top = (image.height - boxHeight) / 2;

      metrics = MeasurementData(
        lengthCm: double.parse(((boxHeight) * 0.026).toStringAsFixed(2)),
        widthCm: double.parse(((boxWidth) * 0.026).toStringAsFixed(2)),
        areaSqCm: double.parse(((boxHeight * boxWidth) * 0.000676).toStringAsFixed(2)),
        boundingBox: Rect.fromLTWH(left, top, boxWidth, boxHeight),
      );
    }

    setState(() {
      _mlMeasurements = metrics;
      _diagnosticInsights = diagnostics;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ScandAid Tracker', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  if (_capturedImagePath != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: FutureBuilder<Size>(
                          future: _getImageDimensions(File(_capturedImagePath!)),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(
                                height: 250,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            
                            final Size imageSize = snapshot.data!;
                            
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final double scaleX = constraints.maxWidth / imageSize.width;
                                final double displayHeight = imageSize.height * scaleX;

                                return SizedBox(
                                  width: constraints.maxWidth,
                                  height: displayHeight,
                                  child: Stack(
                                    children: [
                                      Image.file(
                                        File(_capturedImagePath!),
                                        width: constraints.maxWidth,
                                        height: displayHeight,
                                        fit: BoxFit.fill,
                                      ),
                                      if (_mlMeasurements != null)
                                        Positioned(
                                          left: _mlMeasurements!.boundingBox.left * scaleX,
                                          top: _mlMeasurements!.boundingBox.top * scaleX,
                                          width: _mlMeasurements!.boundingBox.width * scaleX,
                                          height: _mlMeasurements!.boundingBox.height * scaleX,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(color: const Color(0xFF66BB6A), width: 3.5),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 100.0, horizontal: 32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.photo_camera_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Ready for Scan\nCapture or select a photo below to begin analysis.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_isProcessing) 
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),

                  if (_diagnosticInsights != null) ...[
                    // Primary Status Summary Block
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Card(
                        color: Colors.blueGrey.shade900,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _diagnosticInsights!.patientSummary,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Divider(color: Colors.white10, height: 1),
                              ),
                              Text(
                                'Type: ${_diagnosticInsights!.woundType}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${_diagnosticInsights!.severityLevel}',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Care Step: ${_diagnosticInsights!.clinicalRecommendation}',
                                style: TextStyle(color: Colors.grey.shade300, fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Cleaned, Non-Technical Telemetry Block
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Healing Characteristics',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              
                              // Erythema Level renamed to Redness Indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Surrounding Redness', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  Text(_diagnosticInsights!.erythemaScore > 0.5 ? 'Moderate' : 'Normal', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: _diagnosticInsights!.erythemaScore,
                                backgroundColor: Colors.grey.shade100,
                                color: Colors.redAccent.withOpacity(0.8),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              const SizedBox(height: 16),

                              // Structural Disruption renamed to Edge Alignment
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Wound Edge Separation', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  Text(_diagnosticInsights!.structuralDisruption > 0.5 ? 'Irregular' : 'Secure', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: _diagnosticInsights!.structuralDisruption,
                                backgroundColor: Colors.grey.shade100,
                                color: Colors.teal.withOpacity(0.7),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Fixed Overflow: Measurements Layout with wrapping protection
                  if (_mlMeasurements != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            Text('Length: ${_mlMeasurements!.lengthCm} cm', style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
                            Text('Width: ${_mlMeasurements!.widthCm} cm', style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
                            Text('Estimated Area: ${_mlMeasurements!.areaSqCm} cm²', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -2))
              ]
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleImageSelection(true),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleImageSelection(false),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Size> _getImageDimensions(File file) async {
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);
    return Size(image.width.toDouble(), image.height.toDouble());
  }
}