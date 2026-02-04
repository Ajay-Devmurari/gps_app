import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class PermissionService {
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestMedia() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) return true;

    if (Platform.isAndroid) {
      // For Android 13+ handles via requestPermissionExtend,
      // but legacy still needs storage check.
      await Permission.storage.request();
    }
    return ps.isAuth;
  }
}