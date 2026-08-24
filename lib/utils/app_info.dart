import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  AppInfo._();

  static const String brand = 'Orderix';
  static const String author = 'by Smartlogy';
  static const String company = 'Smartlogy Bilişim Medya ve Danışmanlık';

  static String _version = '';
  static String _buildNumber = '';
  static String _brandLine = '$brand · $author';

  static String get brandLine => _brandLine;
  static String get version => _version;
  static String get buildNumber => _buildNumber;

  /// e.g. `1.0.10 (15)` — empty until [init].
  static String get versionLabel {
    if (_version.isEmpty) return '';
    if (_buildNumber.isEmpty) return _version;
    return '$_version ($_buildNumber)';
  }

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
      _brandLine = '$brand ${_shortVersion(info.version)} · $author';
    } catch (_) {
      _version = '';
      _buildNumber = '';
      _brandLine = '$brand · $author';
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
