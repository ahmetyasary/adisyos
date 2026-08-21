import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Tenant-configurable payment method (cash / card / transfer + custom).
class PaymentType {
  const PaymentType({
    required this.id,
    required this.name,
    this.builtin = false,
  });

  final String id;
  final String name;
  final bool builtin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'builtin': builtin,
      };

  factory PaymentType.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? id;
    final builtin = json['builtin'] == true ||
        id == 'cash' ||
        id == 'card' ||
        id == 'transfer';
    return PaymentType(id: id, name: name, builtin: builtin);
  }

  PaymentType copyWith({String? name}) =>
      PaymentType(id: id, name: name ?? this.name, builtin: builtin);
}

/// Built-in methods that every tenant starts with (and cannot delete).
const List<PaymentType> kDefaultPaymentTypes = [
  PaymentType(id: 'cash', name: 'Nakit', builtin: true),
  PaymentType(id: 'card', name: 'Kredi Kartı', builtin: true),
  PaymentType(id: 'transfer', name: 'Havale', builtin: true),
];

List<PaymentType> parsePaymentTypesJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return List<PaymentType>.from(kDefaultPaymentTypes);
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) {
      return List<PaymentType>.from(kDefaultPaymentTypes);
    }
    final parsed = <PaymentType>[];
    final seen = <String>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final pt = PaymentType.fromJson(Map<String, dynamic>.from(item));
      if (pt.id.isEmpty || pt.name.isEmpty || seen.contains(pt.id)) continue;
      seen.add(pt.id);
      parsed.add(pt);
    }
    // Always keep builtins present (even if an older save dropped them).
    for (final d in kDefaultPaymentTypes) {
      if (!seen.contains(d.id)) {
        parsed.insert(
          kDefaultPaymentTypes.indexOf(d).clamp(0, parsed.length),
          d,
        );
        seen.add(d.id);
      }
    }
    return parsed.isEmpty
        ? List<PaymentType>.from(kDefaultPaymentTypes)
        : parsed;
  } catch (_) {
    return List<PaymentType>.from(kDefaultPaymentTypes);
  }
}

String encodePaymentTypesJson(List<PaymentType> types) =>
    jsonEncode(types.map((e) => e.toJson()).toList());

/// Stable icon + accent for a payment method id.
(IconData, Color) paymentTypeVisual(String id) {
  switch (id) {
    case 'cash':
      return (CupertinoIcons.money_dollar, const Color(0xFF52C97F));
    case 'card':
      return (CupertinoIcons.creditcard_fill, const Color(0xFF5DADE2));
    case 'transfer':
      return (CupertinoIcons.building_2_fill, const Color(0xFFAB84F5));
    default:
      const palette = <Color>[
        Color(0xFFFF9500),
        Color(0xFFFF6B6B),
        Color(0xFF20C997),
        Color(0xFF845EF7),
        Color(0xFF339AF0),
        Color(0xFFF06595),
      ];
      final color = palette[id.hashCode.abs() % palette.length];
      return (CupertinoIcons.ticket_fill, color);
  }
}
