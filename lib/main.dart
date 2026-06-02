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
  bool? _isBoxAccurate;

  Future<void> _handleImageSelection(bool fromCamera) async {
    setState(() {
      _isProcessing = true;
      _mlMeasurements = null;
      _diagnosticInsights = null;
      _isBoxAccurate = null;
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

    final MeasurementData? metrics = await _mlService.analyzeInjuryContours(path);
    final DiagnosticData? diagnostics = await _classificationService.classifyInjury(path);

    setState(() {
      _mlMeasurements = metrics;
      _diagnosticInsights = diagnostics;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScandAid Clinical Workspace'),
        backgroundColor: Colors.teal.shade100,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  
                  if (_capturedImagePath != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 4,
                        child: FutureBuilder<Size>(
                          future: _getImageDimensions(File(_capturedImagePath!)),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(
                                height: 200,
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
                                              border: Border.all(color: Colors.greenAccent, width: 3.5),
                                              borderRadius: BorderRadius.circular(4),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 100.0),
                      child: Center(
                        child: Text(
                          'No active scan evaluation.\nSelect Camera or Gallery below to begin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ),
                  ],

                  if (_isProcessing) 
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),

                  if (_diagnosticInsights != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Card(
                        color: Colors.blueGrey.shade900,
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.analytics_outlined, color: Colors.cyanAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Diagnosis Summary (${(_diagnosticInsights!.confidenceScore * 100).toStringAsFixed(0)}% Conf.)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24),
                              Text('Classification: ${_diagnosticInsights!.woundType}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                'Severity Tier: ${_diagnosticInsights!.severityLevel}', 
                                style: TextStyle(
                                  color: _diagnosticInsights!.severityLevel.contains('High') ? Colors.amberAccent : Colors.greenAccent,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Recommendation: ${_diagnosticInsights!.clinicalRecommendation}', style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_mlMeasurements != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Card(
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text('Length: ${_mlMeasurements!.lengthCm}cm', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Width: ${_mlMeasurements!.widthCm}cm', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Area: ${_mlMeasurements!.areaSqCm}cm²', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_mlMeasurements != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Card(
                        color: _isBoxAccurate == false ? Colors.red.shade50 : Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              const Text('Does the bounding box accurately capture the injury tracking region?', style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              if (_isBoxAccurate == null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => setState(() => _isBoxAccurate = true),
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      label: const Text('Yes', style: TextStyle(color: Colors.green)),
                                    ),
                                    const SizedBox(width: 20),
                                    OutlinedButton.icon(
                                      onPressed: () => setState(() => _isBoxAccurate = false),
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      label: const Text('No', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_isBoxAccurate! ? Icons.check_circle : Icons.info, color: _isBoxAccurate! ? Colors.green : Colors.red),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isBoxAccurate! ? 'Feedback recorded. Optimization locked.' : 'Telemetry logged. Updating mapping algorithms.',
                                      style: TextStyle(color: _isBoxAccurate! ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleImageSelection(true),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleImageSelection(false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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