import 'dart:io';
import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'services/ml_service.dart';
import 'models/measurement_data.dart';

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
        useMaterial3: true, // useMaterialDesign is deprecated
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

  String? _capturedImagePath;
  MeasurementData? _mlMeasurements;
  bool? _isBoxAccurate;
  bool _isProcessing = false;
  bool _hasAttemptedScan = false;

  Future<void> _handleImageSelection(bool fromCamera) async {
    setState(() {
      _isBoxAccurate = null;
      _isProcessing = true;
      _mlMeasurements = null;
      _hasAttemptedScan = false;
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

    final MeasurementData? metrics = await _mlService.analyzeInjuryContours(
      path,
    );

    setState(() {
      _mlMeasurements = metrics;
      _isProcessing = false;
      _hasAttemptedScan = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScandAid Precision Tracker'),
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
                  const SizedBox(height: 20),

                  if (_capturedImagePath != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 4,
                        child: FutureBuilder<Size>(
                          future: _getImageDimensions(
                            File(_capturedImagePath!),
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final Size imageSize = snapshot.data!;

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final double scaleX =
                                    constraints.maxWidth / imageSize.width;
                                final double displayHeight =
                                    imageSize.height * scaleX;

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
                                          left:
                                              _mlMeasurements!
                                                  .boundingBox
                                                  .left *
                                              scaleX,
                                          top:
                                              _mlMeasurements!.boundingBox.top *
                                              scaleX,
                                          width:
                                              _mlMeasurements!
                                                  .boundingBox
                                                  .width *
                                              scaleX,
                                          height:
                                              _mlMeasurements!
                                                  .boundingBox
                                                  .height *
                                              scaleX,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.greenAccent,
                                                width: 3.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                      padding: EdgeInsets.symmetric(vertical: 120.0),
                      child: Center(
                        child: Text(
                          'No image loaded yet.\nSelect Camera or Gallery below to begin.',
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

                  if (_hasAttemptedScan &&
                      _mlMeasurements == null &&
                      !_isProcessing)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        color: Colors.orange.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Generic ML Kit Detector found no prominent geometric consumer shapes in this image.',
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_mlMeasurements != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Auto-Contour Data:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                              const Divider(),
                              Text(
                                'Est. Length: ${_mlMeasurements!.lengthCm} cm',
                              ),
                              Text(
                                'Est. Width: ${_mlMeasurements!.widthCm} cm',
                              ),
                              Text(
                                'Calculated Area: ${_mlMeasurements!.areaSqCm} sq cm',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      child: Card(
                        color: _isBoxAccurate == false
                            ? Colors.red.shade50
                            : Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              const Text(
                                'Does this bounding box accurately capture the injury?',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              if (_isBoxAccurate == null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          setState(() => _isBoxAccurate = true),
                                      icon: const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      ),
                                      label: const Text(
                                        'Yes, Looks Good',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: () => setState(
                                        () => _isBoxAccurate = false,
                                      ),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'No, Misaligned',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                )
                              else if (_isBoxAccurate == true)
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Thank you! Feedback saved.',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Understood. Initiating Checkpoint 4 Custom Clinical Classifier...',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      onPressed: _isProcessing
                          ? null
                          : () => _handleImageSelection(true),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleImageSelection(false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
