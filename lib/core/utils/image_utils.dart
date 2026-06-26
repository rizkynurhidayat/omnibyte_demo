import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Checks if the image is too dark by computing the average luminance of its pixels.
  /// A threshold of 50.0 (out of 255) is typically used.
  static Future<bool> isImageTooDark(String imagePath, {double threshold = 50.0}) async {
    return compute(_checkDarknessAsync, _DarknessParams(imagePath, threshold));
  }

  static bool _checkDarknessAsync(_DarknessParams params) {
    try {
      final file = File(params.imagePath);
      if (!file.existsSync()) return false;
      final bytes = file.readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return false;

      double totalLuminance = 0;
      int pixelCount = 0;

      for (final pixel in image) {
        // Luminance formula: 0.299*R + 0.587*G + 0.114*B
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        totalLuminance += luminance;
        pixelCount++;
      }

      if (pixelCount == 0) return false;
      final avgLuminance = totalLuminance / pixelCount;
      return avgLuminance < params.threshold;
    } catch (e) {
      debugPrint("Error checking image darkness: $e");
      return false;
    }
  }

  /// Crops the face area from a horizontal KTP image based on the standard card layout.
  /// (Typically the photo resides on the right side: X ~ 60-95%, Y ~ 15-85%).
  static Future<File> cropKtpFace(String ktpImagePath) async {
    final resultPath = await compute(_cropKtpFaceAsync, ktpImagePath);
    return File(resultPath);
  }

  static String _cropKtpFaceAsync(String ktpImagePath) {
    final file = File(ktpImagePath);
    if (!file.existsSync()) throw Exception("KTP image file not found");
    final bytes = file.readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception("Failed to decode KTP image");

    final width = image.width;
    final height = image.height;

    // Standard coordinates of a face in a horizontal KTP:
    // X: starts at 60% and spans about 35% of the card width
    // Y: starts at 15% and spans about 70% of the card height
    final x = (width * 0.60).toInt();
    final y = (height * 0.15).toInt();
    final w = (width * 0.35).toInt();
    final h = (height * 0.70).toInt();

    // Perform crop with bounds checking
    final cropX = x.clamp(0, width - 1);
    final cropY = y.clamp(0, height - 1);
    final cropW = w.clamp(1, width - cropX);
    final cropH = h.clamp(1, height - cropY);

    final croppedImage = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    // Save the cropped image in the same directory
    final extension = ktpImagePath.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
    final croppedPath = ktpImagePath.replaceAll(extension, '_face$extension');
    final croppedFile = File(croppedPath);
    croppedFile.writeAsBytesSync(img.encodeJpg(croppedImage));

    return croppedPath;
  }

  /// Compresses the image iteratively until its size is under the specified threshold (default 1MB).
  static Future<File> compressImage(String imagePath, {int maxSizeBytes = 1024 * 1024}) async {
    final resultPath = await compute(
      _compressImageAsync,
      _CompressParams(imagePath, maxSizeBytes),
    );
    return File(resultPath);
  }

  static String _compressImageAsync(_CompressParams params) {
    final file = File(params.imagePath);
    if (!file.existsSync()) throw Exception("Image file not found for compression");
    
    int size = file.lengthSync();
    if (size <= params.maxSizeBytes) {
      return params.imagePath; // No compression needed
    }

    final bytes = file.readAsBytesSync();
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) throw Exception("Failed to decode image for compression");
    var activeImage = decodedImage;

    int quality = 85;
    List<int> compressedBytes;
    
    do {
      compressedBytes = img.encodeJpg(activeImage, quality: quality);
      size = compressedBytes.length;
      if (size <= params.maxSizeBytes) break;

      quality -= 15;
      if (quality < 25) {
        // If quality reduction is not enough, downscale the image resolution
        activeImage = img.copyResize(activeImage, width: (activeImage.width * 0.8).toInt());
        quality = 80; // Reset quality for downscaled image
      }
    } while (size > params.maxSizeBytes && quality >= 25);

    // Write compressed image
    final extension = params.imagePath.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
    final compressedPath = params.imagePath.replaceAll(extension, '_compressed$extension');
    final compressedFile = File(compressedPath);
    compressedFile.writeAsBytesSync(compressedBytes);

    return compressedPath;
  }
}

class _DarknessParams {
  final String imagePath;
  final double threshold;
  _DarknessParams(this.imagePath, this.threshold);
}

class _CompressParams {
  final String imagePath;
  final int maxSizeBytes;
  _CompressParams(this.imagePath, this.maxSizeBytes);
}
