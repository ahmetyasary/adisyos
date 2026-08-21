import 'dart:convert';

/// Tenant-configurable thermal receipt (adisyon) layout.
class ReceiptLayout {
  const ReceiptLayout({
    this.showCompanyName = true,
    this.showTable = true,
    this.showDateTime = true,
    this.showItems = true,
    this.showDiscountBreakdown = true,
    this.showTotal = true,
    this.showFooter = true,
    this.headerNote = '',
    this.footerText = 'Teşekkür ederiz!',
    this.fontSize = 'md',
    this.paperSize = 'roll80',
  });

  final bool showCompanyName;
  final bool showTable;
  final bool showDateTime;
  final bool showItems;
  final bool showDiscountBreakdown;
  final bool showTotal;
  final bool showFooter;

  /// Optional line under the company name (address, phone, etc.).
  final String headerNote;

  /// Closing message at the bottom of the slip.
  final String footerText;

  /// `sm` | `md` | `lg` — scales body / title fonts.
  final String fontSize;

  /// `roll58` | `roll80` | `a4` — physical paper for print dialog.
  final String paperSize;

  static const ReceiptLayout defaults = ReceiptLayout();

  double get titleFont {
    switch (fontSize) {
      case 'sm':
        return 13;
      case 'lg':
        return 18;
      default:
        return 16;
    }
  }

  double get bodyFont {
    switch (fontSize) {
      case 'sm':
        return 10;
      case 'lg':
        return 13;
      default:
        return 12;
    }
  }

  double get metaFont {
    switch (fontSize) {
      case 'sm':
        return 8;
      case 'lg':
        return 11;
      default:
        return 10;
    }
  }

  double get totalFont {
    switch (fontSize) {
      case 'sm':
        return 12;
      case 'lg':
        return 16;
      default:
        return 14;
    }
  }

  ReceiptLayout copyWith({
    bool? showCompanyName,
    bool? showTable,
    bool? showDateTime,
    bool? showItems,
    bool? showDiscountBreakdown,
    bool? showTotal,
    bool? showFooter,
    String? headerNote,
    String? footerText,
    String? fontSize,
    String? paperSize,
  }) {
    return ReceiptLayout(
      showCompanyName: showCompanyName ?? this.showCompanyName,
      showTable: showTable ?? this.showTable,
      showDateTime: showDateTime ?? this.showDateTime,
      showItems: showItems ?? this.showItems,
      showDiscountBreakdown:
          showDiscountBreakdown ?? this.showDiscountBreakdown,
      showTotal: showTotal ?? this.showTotal,
      showFooter: showFooter ?? this.showFooter,
      headerNote: headerNote ?? this.headerNote,
      footerText: footerText ?? this.footerText,
      fontSize: fontSize ?? this.fontSize,
      paperSize: paperSize ?? this.paperSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'showCompanyName': showCompanyName,
        'showTable': showTable,
        'showDateTime': showDateTime,
        'showItems': showItems,
        'showDiscountBreakdown': showDiscountBreakdown,
        'showTotal': showTotal,
        'showFooter': showFooter,
        'headerNote': headerNote,
        'footerText': footerText,
        'fontSize': fontSize,
        'paperSize': paperSize,
      };

  factory ReceiptLayout.fromJson(Map<String, dynamic> json) {
    String size = (json['fontSize'] as String?) ?? 'md';
    if (size != 'sm' && size != 'md' && size != 'lg') size = 'md';
    String paper = (json['paperSize'] as String?) ?? 'roll80';
    if (paper != 'roll58' && paper != 'roll80' && paper != 'a4') {
      paper = 'roll80';
    }
    return ReceiptLayout(
      showCompanyName: json['showCompanyName'] as bool? ?? true,
      showTable: json['showTable'] as bool? ?? true,
      showDateTime: json['showDateTime'] as bool? ?? true,
      showItems: json['showItems'] as bool? ?? true,
      showDiscountBreakdown: json['showDiscountBreakdown'] as bool? ?? true,
      showTotal: json['showTotal'] as bool? ?? true,
      showFooter: json['showFooter'] as bool? ?? true,
      headerNote: (json['headerNote'] as String?) ?? '',
      footerText: (json['footerText'] as String?) ?? 'Teşekkür ederiz!',
      fontSize: size,
      paperSize: paper,
    );
  }
}

ReceiptLayout parseReceiptLayoutJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return ReceiptLayout.defaults;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return ReceiptLayout.defaults;
    return ReceiptLayout.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return ReceiptLayout.defaults;
  }
}

String encodeReceiptLayoutJson(ReceiptLayout layout) =>
    jsonEncode(layout.toJson());
