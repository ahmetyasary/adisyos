import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  AppInfo._();

  static const String _brand = 'Orderix';
  static const String _author = 'by Smartlogy';

  static String _brandLine = '$_brand · $_author';

  static String get brandLine => _brandLine;

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _brandLine = '$_brand ${_shortVersion(info.version)} · $_author';
    } catch (_) {
      _brandLine = '$_brand · $_author';
    }
  }

  static String _shortVersion(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw.split('.');
    if (parts.length >= 2) {
      return 'v${parts[0]}.${parts[1]}';
    }
    return 'v$raw';
  }
}
