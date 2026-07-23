import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Checks if the image is too dark by computing the average luminance of its pixels.
  /// A threshold of 50.0 (out of 255) is typically used.
  static Future<bool> isImageTooDark(String imagePath, {double threshold = 50.0}) async {
    if (imagePath.startsWith('simulated_')) return false;
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

  /// Crops the KTP card area from the full camera frame.
  static Future<File> cropKtpCard(String ktpImagePath) async {
    if (ktpImagePath.startsWith('simulated_')) return File(ktpImagePath);
    final resultPath = await compute(_cropKtpCardAsync, ktpImagePath);
    return File(resultPath);
  }

  static String _cropKtpCardAsync(String ktpImagePath) {
    if (ktpImagePath.startsWith('simulated_')) return ktpImagePath;
    final file = File(ktpImagePath);
    if (!file.existsSync()) throw Exception("KTP image file not found");
    final bytes = file.readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception("Failed to decode KTP image");
    
    // Bake EXIF orientation so pixels are rotated correctly
    image = img.bakeOrientation(image);

    final imgWidth = image.width;
    final imgHeight = image.height;

    // Based on KtpCutoutPainter: width = 85%, aspect ratio = 1.586
    final cropW = (imgWidth * 0.85).toInt();
    final cropH = (cropW / 1.586).toInt();

    // Center X
    final cropX = ((imgWidth - cropW) / 2).toInt().clamp(0, imgWidth - 1);
    
    // Center Y, shifted up slightly to match the -20 logical pixels in painter (~2.5% of height)
    final cropY = ((imgHeight - cropH) / 2 - (imgHeight * 0.025)).toInt().clamp(0, imgHeight - 1);

    final finalCropW = cropW.clamp(1, imgWidth - cropX);
    final finalCropH = cropH.clamp(1, imgHeight - cropY);

    final croppedImage = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: finalCropW,
      height: finalCropH,
    );

    final extension = ktpImagePath.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
    final croppedPath = ktpImagePath.replaceAll(extension, '_card$extension');
    final croppedFile = File(croppedPath);
    croppedFile.writeAsBytesSync(img.encodeJpg(croppedImage));

    return croppedPath;
  }

  /// Crops the face area from a horizontal KTP/SIM/Passport image based on the standard card layout.
  /// (Typically the photo resides on the right side for KTP: X ~ 60-95%, Y ~ 15-85%,
  /// or left side for SIM/Passport: X ~ 5-40%, Y ~ 15-85%).
  static Future<File> cropKtpFace(String ktpImagePath, {bool isFaceOnLeft = false}) async {
    if (ktpImagePath.startsWith('simulated_')) return File('simulated_ktp_face.jpg');
    final resultPath = await compute(_cropKtpFaceAsync, _CropFaceCardParams(ktpImagePath, isFaceOnLeft));
    return File(resultPath);
  }

  static String _cropKtpFaceAsync(_CropFaceCardParams params) {
    if (params.imagePath.startsWith('simulated_')) return 'simulated_ktp_face.jpg';
    final file = File(params.imagePath);
    if (!file.existsSync()) throw Exception("Document image file not found");
    final bytes = file.readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception("Failed to decode Document image");
    
    // Bake EXIF orientation so pixels are rotated correctly
    image = img.bakeOrientation(image);

    final width = image.width;
    final height = image.height;

    // Standard coordinates of a face in a horizontal card layout:
    // Left side (SIM/Passport): X starts at 5% and spans about 35% of the card width
    // Right side (KTP): X starts at 60% and spans about 35% of the card width
    // Y starts at 15% and spans about 70% of the card height for both
    final x = params.isFaceOnLeft ? (width * 0.05).toInt() : (width * 0.60).toInt();
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
    final extension = params.imagePath.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
    final croppedPath = params.imagePath.replaceAll(extension, '_face$extension');
    final croppedFile = File(croppedPath);
    croppedFile.writeAsBytesSync(img.encodeJpg(croppedImage));

    return croppedPath;
  }

  /// Crops the face area from a selfie image based on the detected bounding box coordinates.
  static Future<File> cropFace(String imagePath, int left, int top, int width, int height, {String suffix = '_face'}) async {
    if (imagePath.startsWith('simulated_')) return File('simulated_selfie_face.jpg');
    final resultPath = await compute(
      _cropFaceAsync,
      _CropFaceParams(imagePath, left, top, width, height, suffix),
    );
    return File(resultPath);
  }

  static String _cropFaceAsync(_CropFaceParams params) {
    if (params.imagePath.startsWith('simulated_')) {
      return 'simulated_selfie_face.jpg';
    }
    final file = File(params.imagePath);
    if (!file.existsSync()) throw Exception("Image file not found for face cropping");
    final bytes = file.readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception("Failed to decode image for face cropping");
    
    // Bake EXIF orientation
    image = img.bakeOrientation(image);

    final imgWidth = image.width;
    final imgHeight = image.height;

    final x = params.left.clamp(0, imgWidth - 1);
    final y = params.top.clamp(0, imgHeight - 1);
    final w = params.width.clamp(1, imgWidth - x);
    final h = params.height.clamp(1, imgHeight - y);

    final croppedImage = img.copyCrop(
      image,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    final extension = params.imagePath.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
    final croppedPath = params.imagePath.replaceAll(extension, '${params.suffix}$extension');
    final croppedFile = File(croppedPath);
    croppedFile.writeAsBytesSync(img.encodeJpg(croppedImage));

    return croppedPath;
  }

  /// Compresses the image iteratively until its size is under the specified threshold (default 1MB).
  static Future<File> compressImage(String imagePath, {int maxSizeBytes = 1024 * 1024}) async {
    if (imagePath.startsWith('simulated_')) return File(imagePath);
    final resultPath = await compute(
      _compressImageAsync,
      _CompressParams(imagePath, maxSizeBytes),
    );
    return File(resultPath);
  }

  static String _compressImageAsync(_CompressParams params) {
    if (params.imagePath.startsWith('simulated_')) {
      return params.imagePath;
    }
    final file = File(params.imagePath);
    if (!file.existsSync()) throw Exception("Image file not found for compression");
    
    final bytes = file.readAsBytesSync();
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) throw Exception("Failed to decode image for compression");
    
    // Always bake EXIF orientation so the final image has correct pixel rotation
    var activeImage = img.bakeOrientation(decodedImage);

    int quality = 85;
    List<int> compressedBytes;
    int size;
    
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

class _CropFaceParams {
  final String imagePath;
  final int left;
  final int top;
  final int width;
  final int height;
  final String suffix;
  _CropFaceParams(this.imagePath, this.left, this.top, this.width, this.height, this.suffix);
}

class _CropFaceCardParams {
  final String imagePath;
  final bool isFaceOnLeft;
  _CropFaceCardParams(this.imagePath, this.isFaceOnLeft);
}
