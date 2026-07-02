import 'dart:io';

import 'package:flutter/material.dart';

import '../models/measurement_data.dart';

class MeasurementOverlay extends StatelessWidget {
  final String imagePath;
  final MeasurementData? measurements;

  const MeasurementOverlay({
    super.key,
    required this.imagePath,
    this.measurements,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _getImageDimensions(File(imagePath)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final imageSize = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final scaleX = constraints.maxWidth / imageSize.width;
            final displayHeight = imageSize.height * scaleX;

            return SizedBox(
              width: constraints.maxWidth,
              height: displayHeight,
              child: Stack(
                children: [
                  Image.file(
                    File(imagePath),
                    width: constraints.maxWidth,
                    height: displayHeight,
                    fit: BoxFit.fill,
                  ),
                  if (measurements != null)
                    Positioned(
                      left: measurements!.boundingBox.left * scaleX,
                      top: measurements!.boundingBox.top * scaleX,
                      width: measurements!.boundingBox.width * scaleX,
                      height: measurements!.boundingBox.height * scaleX,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: measurements!.isEstimated
                                ? Colors.orange
                                : const Color(0xFF66BB6A),
                            width: 3.5,
                          ),
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
    );
  }

  Future<Size> _getImageDimensions(File file) async {
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);
    return Size(image.width.toDouble(), image.height.toDouble());
  }
}
