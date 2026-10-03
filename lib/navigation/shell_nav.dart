import 'package:get/get.dart';

/// Section the shell should open after a notification tap.
///
/// Set before [AppShell] exists (cold start, PIN screen) and consumed when
/// the shell mounts. Later taps are observed while the shell is alive.
class ShellNav {
  ShellNav._();

  static final request = RxnString();

  static void open(String sectionId) {
    request.value = sectionId;
  }

  static String? consume() {
    final id = request.value;
    request.value = null;
    return id;
  }
}
