import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../providers/analysis_provider.dart';
import '../widgets/grid_overlay.dart';
import 'results_screen.dart';

class CameraCaptureScreen extends StatelessWidget {
  const CameraCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        if (provider.status == AnalysisStatus.complete && provider.currentRecord != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            await context.read<HistoryProvider>().loadRecords();
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResultsScreen(record: provider.currentRecord!),
              ),
            );
            provider.reset();
          });
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text('Scan Injury', style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  provider.showGridOverlay ? Icons.grid_on : Icons.grid_off,
                  color: Colors.teal,
                ),
                onPressed: provider.toggleGridOverlay,
                tooltip: 'Toggle alignment grid',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  color: Colors.grey.shade200,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.photo_camera_outlined,
                                          size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 32),
                                        child: Text(
                                          'Position the injury within the guide frame.\nKeep the camera steady and well-lit.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (provider.showGridOverlay) const GridOverlay(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (provider.isProcessing)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Analyzing injury...'),
                            ],
                          ),
                        ),
                      if (provider.status == AnalysisStatus.error)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      provider.errorMessage ?? 'Something went wrong.',
                                      style: TextStyle(color: Colors.red.shade900),
                                    ),
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
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: provider.isProcessing ? null : provider.captureFromCamera,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isProcessing ? null : provider.selectFromGallery,
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
      },
    );
  }
}
