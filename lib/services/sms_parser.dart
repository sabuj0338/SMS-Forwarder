/// Parsed fields from common Bangladeshi MFS / bank SMS formats.
class ParsedSms {
  final double? amount;
  final String? txnId;
  final String? type; // credit | debit | unknown
  final String? counterparty;
  final String? currency;

  const ParsedSms({
    this.amount,
    this.txnId,
    this.type,
    this.counterparty,
    this.currency,
  });

  bool get hasAny =>
      amount != null ||
      (txnId != null && txnId!.isNotEmpty) ||
      (type != null && type != 'unknown') ||
      (counterparty != null && counterparty!.isNotEmpty);

  Map<String, dynamic> toJson() => {
        if (amount != null) 'amount': amount,
        if (txnId != null) 'txn_id': txnId,
        if (type != null) 'type': type,
        if (counterparty != null) 'counterparty': counterparty,
        if (currency != null) 'currency': currency,
      };
}

class SmsParser {
  static final _amountPatterns = <RegExp>[
    RegExp(r'(?:tk|bdt|৳)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false),
    RegExp(r'([\d,]+(?:\.\d+)?)\s*(?:tk|bdt|৳)', caseSensitive: false),
    RegExp(
      r'(?:amount|amt)[:\s]*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ),
  ];

  static final _txnPatterns = <RegExp>[
    RegExp(
      r'(?:txn\s*id|txnid|trx\s*id|trxid|transaction\s*id|ref)[:\s#]*([A-Za-z0-9]+)',
      caseSensitive: false,
    ),
  ];

  static final _phonePattern = RegExp(r'(?:\+?88)?(01[3-9]\d{8})');

  static ParsedSms parse(String body) {
    final lower = body.toLowerCase();
    final amount = _parseAmount(body);
    final txnId = _parseTxnId(body);
    final type = _parseType(lower);
    final counterparty = _parseCounterparty(body, lower);
    final currency = amount != null ? 'BDT' : null;

    return ParsedSms(
      amount: amount,
      txnId: txnId,
      type: type,
      counterparty: counterparty,
      currency: currency,
    );
  }

  static double? _parseAmount(String body) {
    for (final re in _amountPatterns) {
      final m = re.firstMatch(body);
      if (m == null) continue;
      final raw = m.group(1)?.replaceAll(',', '');
      if (raw == null) continue;
      return double.tryParse(raw);
    }
    return null;
  }

  static String? _parseTxnId(String body) {
    for (final re in _txnPatterns) {
      final m = re.firstMatch(body);
      final id = m?.group(1);
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  static String _parseType(String lower) {
    final creditHints = [
      'received',
      'credited',
      'cash in',
      'deposit',
      'পেয়েছেন',
      'জমা',
    ];
    final debitHints = [
      'sent',
      'debited',
      'payment',
      'paid',
      'cash out',
      'withdraw',
      'পাঠানো',
      'উত্তোলন',
    ];
    if (creditHints.any(lower.contains)) return 'credit';
    if (debitHints.any(lower.contains)) return 'debit';
    return 'unknown';
  }

  static String? _parseCounterparty(String body, String lower) {
    // Prefer "from" for credit, "to" for debit.
    final fromMatch = RegExp(
      r'from\s+(?:\+?88)?(01[3-9]\d{8})',
      caseSensitive: false,
    ).firstMatch(body);
    final toMatch = RegExp(
      r'to\s+(?:\+?88)?(01[3-9]\d{8})',
      caseSensitive: false,
    ).firstMatch(body);

    if (lower.contains('received') || lower.contains('credited')) {
      return fromMatch?.group(1) ?? toMatch?.group(1);
    }
    if (lower.contains('sent') || lower.contains('payment')) {
      return toMatch?.group(1) ?? fromMatch?.group(1);
    }

    return fromMatch?.group(1) ??
        toMatch?.group(1) ??
        _phonePattern.firstMatch(body)?.group(1);
  }
}
