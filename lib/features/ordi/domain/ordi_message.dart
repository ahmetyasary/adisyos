/// Which brain produced an assistant message.
enum OrdiSource {
  /// Answered by Gemini through the `ordi` edge function.
  gemini,

  /// Answered offline by [OrdiLocalBrain] — the edge function was unreachable,
  /// out of quota, or the device is offline.
  local,

  /// Nothing could answer; the bubble renders as a soft error.
  failure,
}

enum OrdiRole { user, assistant }

class OrdiMessage {
  const OrdiMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.source,
  });

  OrdiMessage.user(this.text, {DateTime? at})
      : role = OrdiRole.user,
        source = null,
        createdAt = at ?? DateTime.now();

  OrdiMessage.assistant(this.text, {required this.source, DateTime? at})
      : role = OrdiRole.assistant,
        createdAt = at ?? DateTime.now();

  final OrdiRole role;
  final String text;
  final DateTime createdAt;

  /// Null for user messages.
  final OrdiSource? source;

  bool get isUser => role == OrdiRole.user;
  bool get isFailure => source == OrdiSource.failure;

  /// Column value for `ordi_chats.source`.
  String? get sourceKey => switch (source) {
        OrdiSource.gemini => 'gemini',
        OrdiSource.local => 'local',
        OrdiSource.failure => 'error',
        null => null,
      };

  static OrdiSource? sourceFromKey(String? key) => switch (key) {
        'gemini' => OrdiSource.gemini,
        'local' => OrdiSource.local,
        'error' => OrdiSource.failure,
        _ => null,
      };
}
