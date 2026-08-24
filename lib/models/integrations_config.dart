import 'dart:convert';

/// POS / ÖKC provider keys for the restaurant register.
enum PosProvider {
  hugin,
  ingenico,
  beko,
  pavo,
  inpos,
  other,
}

extension PosProviderX on PosProvider {
  String get label => switch (this) {
        PosProvider.hugin => 'Hugin',
        PosProvider.ingenico => 'Ingenico',
        PosProvider.beko => 'Beko',
        PosProvider.pavo => 'Pavo',
        PosProvider.inpos => 'Inpos',
        PosProvider.other => 'Diğer / Özel',
      };
}

class PosIntegrationConfig {
  const PosIntegrationConfig({
    this.enabled = false,
    this.provider = PosProvider.hugin,
    this.merchantId = '',
    this.terminalId = '',
    this.apiKey = '',
    this.endpoint = '',
  });

  final bool enabled;
  final PosProvider provider;
  final String merchantId;
  final String terminalId;
  final String apiKey;
  final String endpoint;

  bool get isConfigured =>
      merchantId.trim().isNotEmpty ||
      terminalId.trim().isNotEmpty ||
      apiKey.trim().isNotEmpty;

  String get statusLabel {
    if (!enabled) return 'Kapalı';
    if (!isConfigured) return 'Eksik bilgi';
    return 'Aktif';
  }

  PosIntegrationConfig copyWith({
    bool? enabled,
    PosProvider? provider,
    String? merchantId,
    String? terminalId,
    String? apiKey,
    String? endpoint,
  }) =>
      PosIntegrationConfig(
        enabled: enabled ?? this.enabled,
        provider: provider ?? this.provider,
        merchantId: merchantId ?? this.merchantId,
        terminalId: terminalId ?? this.terminalId,
        apiKey: apiKey ?? this.apiKey,
        endpoint: endpoint ?? this.endpoint,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider.name,
        'merchantId': merchantId,
        'terminalId': terminalId,
        'apiKey': apiKey,
        'endpoint': endpoint,
      };

  factory PosIntegrationConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PosIntegrationConfig();
    final providerName = json['provider'] as String?;
    final provider = PosProvider.values
            .where((e) => e.name == providerName)
            .firstOrNull ??
        PosProvider.hugin;
    return PosIntegrationConfig(
      enabled: json['enabled'] == true,
      provider: provider,
      merchantId: '${json['merchantId'] ?? ''}',
      terminalId: '${json['terminalId'] ?? ''}',
      apiKey: '${json['apiKey'] ?? ''}',
      endpoint: '${json['endpoint'] ?? ''}',
    );
  }
}

enum MarketplaceChannel {
  getir,
  trendyolGo,
  yemeksepeti,
}

extension MarketplaceChannelX on MarketplaceChannel {
  String get id => name;

  String get label => switch (this) {
        MarketplaceChannel.getir => 'Getir',
        MarketplaceChannel.trendyolGo => 'Trendyol Go',
        MarketplaceChannel.yemeksepeti => 'Yemeksepeti',
      };

  String get subtitle => switch (this) {
        MarketplaceChannel.getir => 'Getir Yemek siparişleri',
        MarketplaceChannel.trendyolGo => 'Uber Eats / Trendyol Go',
        MarketplaceChannel.yemeksepeti => 'Yemeksepeti siparişleri',
      };

  String get brandHint => switch (this) {
        MarketplaceChannel.getir => 'Getir partner paneli',
        MarketplaceChannel.trendyolGo => 'Trendyol Go satıcı paneli',
        MarketplaceChannel.yemeksepeti => 'Yemeksepeti restoran paneli',
      };
}

class MarketplaceIntegrationConfig {
  const MarketplaceIntegrationConfig({
    required this.channel,
    this.enabled = false,
    this.restaurantId = '',
    this.apiKey = '',
    this.apiSecret = '',
  });

  final MarketplaceChannel channel;
  final bool enabled;
  final String restaurantId;
  final String apiKey;
  final String apiSecret;

  bool get isConfigured =>
      restaurantId.trim().isNotEmpty ||
      apiKey.trim().isNotEmpty ||
      apiSecret.trim().isNotEmpty;

  String get statusLabel {
    if (!enabled) return 'Kapalı';
    if (!isConfigured) return 'Eksik bilgi';
    return 'Aktif';
  }

  MarketplaceIntegrationConfig copyWith({
    MarketplaceChannel? channel,
    bool? enabled,
    String? restaurantId,
    String? apiKey,
    String? apiSecret,
  }) =>
      MarketplaceIntegrationConfig(
        channel: channel ?? this.channel,
        enabled: enabled ?? this.enabled,
        restaurantId: restaurantId ?? this.restaurantId,
        apiKey: apiKey ?? this.apiKey,
        apiSecret: apiSecret ?? this.apiSecret,
      );

  Map<String, dynamic> toJson() => {
        'channel': channel.name,
        'enabled': enabled,
        'restaurantId': restaurantId,
        'apiKey': apiKey,
        'apiSecret': apiSecret,
      };

  factory MarketplaceIntegrationConfig.fromJson(
    MarketplaceChannel channel,
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return MarketplaceIntegrationConfig(channel: channel);
    }
    return MarketplaceIntegrationConfig(
      channel: channel,
      enabled: json['enabled'] == true,
      restaurantId: '${json['restaurantId'] ?? ''}',
      apiKey: '${json['apiKey'] ?? ''}',
      apiSecret: '${json['apiSecret'] ?? ''}',
    );
  }
}

class IntegrationsConfig {
  const IntegrationsConfig({
    this.pos = const PosIntegrationConfig(),
    this.marketplaces = const [],
  });

  final PosIntegrationConfig pos;
  final List<MarketplaceIntegrationConfig> marketplaces;

  static IntegrationsConfig defaults() => IntegrationsConfig(
        pos: const PosIntegrationConfig(),
        marketplaces: [
          for (final c in MarketplaceChannel.values)
            MarketplaceIntegrationConfig(channel: c),
        ],
      );

  MarketplaceIntegrationConfig channel(MarketplaceChannel c) {
    for (final m in marketplaces) {
      if (m.channel == c) return m;
    }
    return MarketplaceIntegrationConfig(channel: c);
  }

  int get activeMarketplaceCount =>
      marketplaces.where((m) => m.enabled && m.isConfigured).length;

  IntegrationsConfig copyWith({
    PosIntegrationConfig? pos,
    List<MarketplaceIntegrationConfig>? marketplaces,
  }) =>
      IntegrationsConfig(
        pos: pos ?? this.pos,
        marketplaces: marketplaces ?? this.marketplaces,
      );

  Map<String, dynamic> toJson() => {
        'pos': pos.toJson(),
        'marketplaces': marketplaces.map((e) => e.toJson()).toList(),
      };

  factory IntegrationsConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return IntegrationsConfig.defaults();
    final posRaw = json['pos'];
    final pos = PosIntegrationConfig.fromJson(
      posRaw is Map<String, dynamic>
          ? posRaw
          : (posRaw is Map ? Map<String, dynamic>.from(posRaw) : null),
    );

    final byChannel = <MarketplaceChannel, MarketplaceIntegrationConfig>{};
    final list = json['marketplaces'];
    if (list is List) {
      for (final e in list) {
        Map<String, dynamic>? map;
        if (e is Map<String, dynamic>) {
          map = e;
        } else if (e is Map) {
          map = Map<String, dynamic>.from(e);
        }
        if (map == null) continue;
        final name = map['channel'] as String?;
        final channel = MarketplaceChannel.values
            .where((c) => c.name == name)
            .firstOrNull;
        if (channel == null) continue;
        byChannel[channel] =
            MarketplaceIntegrationConfig.fromJson(channel, map);
      }
    }

    return IntegrationsConfig(
      pos: pos,
      marketplaces: [
        for (final c in MarketplaceChannel.values)
          byChannel[c] ?? MarketplaceIntegrationConfig(channel: c),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

String encodeIntegrationsConfig(IntegrationsConfig config) =>
    jsonEncode(config.toJson());

IntegrationsConfig parseIntegrationsConfig(String? raw) {
  if (raw == null || raw.trim().isEmpty) return IntegrationsConfig.defaults();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return IntegrationsConfig.fromJson(decoded);
    }
    if (decoded is Map) {
      return IntegrationsConfig.fromJson(Map<String, dynamic>.from(decoded));
    }
    return IntegrationsConfig.defaults();
  } catch (_) {
    return IntegrationsConfig.defaults();
  }
}
