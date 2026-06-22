import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  PermissionHelper._();

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> checkCameraPermission() async {
    return Permission.camera.isGranted;
  }

  static Future<bool> checkNotificationPermission() async {
    return Permission.notification.isGranted;
  }
}
