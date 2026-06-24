class AirdropItem {
  final String token;
  final String name;
  final String date;
  final String time;
  final dynamic points;
  final String amount;
  final String type;   // "grab" | "warning"
  final int? phase;
  final String status;
  final bool futuresListed;
  final int systemTimestamp;

  // Warning / 扩展字段
  final String? totalAmount;
  final String? id;
  final String? contractAddress;
  final int? chainId;
  final String? txHash;
  final String? txTime;
  final String? d976TxHash;
  final String? d976TxTime;
  final String? confirmedAt;
  final String? confirmSource;
  final bool hasHomonym;
  final bool pairedTransfer;
  final String? pairedFrom;
  final String? pairedTxHash;
  final int? pairedTimeDiff;

  // History-specific fields
  final bool? completed;
  final bool? spotListed;
  final double? marketCap;
  final double? fdv;

  AirdropItem({
    required this.token,
    required this.name,
    required this.date,
    required this.time,
    required this.points,
    required this.amount,
    required this.type,
    this.phase,
    required this.status,
    required this.futuresListed,
    required this.systemTimestamp,
    this.totalAmount,
    this.id,
    this.contractAddress,
    this.chainId,
    this.txHash,
    this.txTime,
    this.d976TxHash,
    this.d976TxTime,
    this.confirmedAt,
    this.confirmSource,
    this.hasHomonym = false,
    this.pairedTransfer = false,
    this.pairedFrom,
    this.pairedTxHash,
    this.pairedTimeDiff,
    this.completed,
    this.spotListed,
    this.marketCap,
    this.fdv,
  });

  /// 显示名称：优先使用 name，其次 token
  String get displayName {
    if (name.isNotEmpty) return name;
    if (token.isNotEmpty) return token;
    return 'Unknown';
  }

  /// 简称：优先使用 token，其次 name 截取
  String get shortName {
    if (token.isNotEmpty) return token;
    if (name.isNotEmpty) return name.length > 6 ? name.substring(0, 6) : name;
    return '?';
  }

  /// 比较日期/时间，用于排序
  int compareDateTime(AirdropItem other) {
    final dateCompare = other.date.compareTo(date); // 降序
    if (dateCompare != 0) return dateCompare;
    return other.time.compareTo(time); // 降序
  }

  /// 状态文本
  String get statusText {
    switch (status) {
      case 'announced':
        return '已公告';
      case 'ongoing':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'upcoming':
        return '即将开始';
      default:
        return status;
    }
  }

  /// 是否为警告类型
  bool get isWarning => type == 'warning';

  /// 类型中文标签
  String get typeLabel => isWarning ? '预警' : '抢购';

  factory AirdropItem.fromJson(Map<String, dynamic> json) {
    return AirdropItem(
      token: _parseString(json['token']) ?? '',
      name: _parseString(json['name']) ?? '',
      date: _parseString(json['date']) ?? '',
      time: _parseString(json['time']) ?? '',
      points: json['points'],
      amount: _parseString(json['amount']) ?? '',
      type: _parseString(json['type']) ?? '',
      phase: _parseInt(json['phase']),
      status: _parseString(json['status']) ?? '',
      futuresListed: _parseBool(json['futures_listed']) ?? false,
      systemTimestamp: _parseInt(json['system_timestamp']) ?? 0,

      // Warning / 扩展字段
      totalAmount: _parseString(json['total_amount']),
      id: _parseString(json['id']),
      contractAddress: _parseString(json['contract_address']),
      chainId: _parseInt(json['chain_id']),
      txHash: _parseString(json['tx_hash']),
      txTime: _parseString(json['tx_time']),
      d976TxHash: _parseString(json['d976_tx_hash']),
      d976TxTime: _parseString(json['d976_tx_time']),
      confirmedAt: _parseString(json['confirmed_at']),
      confirmSource: _parseString(json['confirm_source']),
      hasHomonym: _parseBool(json['has_homonym']) ?? false,
      pairedTransfer: _parseBool(json['paired_transfer']) ?? false,
      pairedFrom: _parseString(json['paired_from']),
      pairedTxHash: _parseString(json['paired_tx_hash']),
      pairedTimeDiff: _parseInt(json['paired_time_diff']),

      // History-specific fields
      completed: _parseBool(json['completed']),
      spotListed: _parseBool(json['spot_listed']),
      marketCap: _parseDouble(json['market_cap']),
      fdv: _parseDouble(json['fdv']),
    );
  }
}

class AlphaCheckin {
  final String key;
  final int count;

  AlphaCheckin({required this.key, required this.count});

  factory AlphaCheckin.fromJson(Map<String, dynamic> json) {
    return AlphaCheckin(
      key: _parseString(json['key']) ?? '',
      count: _parseInt(json['count']) ?? 0,
    );
  }
}

class TopToken {
  final String symbol;
  final String buyQuoteVolume;
  final int? trades;
  final String? avgBuyAmount;

  TopToken({
    required this.symbol,
    required this.buyQuoteVolume,
    this.trades,
    this.avgBuyAmount,
  });

  /// 格式化买入次数
  String get formattedTrades {
    if (trades == null) return '-';
    return _formatNumber(trades!);
  }

  /// 格式化平均买入金额
  String get formattedAvgBuy {
    if (avgBuyAmount == null || avgBuyAmount!.isEmpty) return '-';
    final value = double.tryParse(avgBuyAmount!);
    if (value == null) return avgBuyAmount!;
    return value.toStringAsFixed(2);
  }

  /// 格式化交易量
  String get formattedVolume {
    final value = double.tryParse(buyQuoteVolume);
    if (value == null) return buyQuoteVolume;
    return _formatNumber(value.toInt());
  }

  factory TopToken.fromJson(Map<String, dynamic> json) {
    return TopToken(
      symbol: _parseString(json['symbol']) ?? '',
      buyQuoteVolume: _parseString(json['buyQuoteVolume']) ?? '0',
      trades: _parseInt(json['trades']),
      avgBuyAmount: _parseString(json['avgBuyAmount']),
    );
  }
}

/// 首页数据响应
class DataResponse {
  final List<AirdropItem> airdrops;
  final List<AlphaCheckin> alphaCheckins;
  final String lastRolloverDate;
  final List<TopToken> top3Tokens;
  final double bnbPriceUsd;
  final int bnbPriceTs;
  final String bnbPriceSource;

  DataResponse({
    required this.airdrops,
    required this.alphaCheckins,
    required this.lastRolloverDate,
    required this.top3Tokens,
    required this.bnbPriceUsd,
    required this.bnbPriceTs,
    required this.bnbPriceSource,
  });

  factory DataResponse.fromJson(Map<String, dynamic> json) {
    return DataResponse(
      airdrops: (json['airdrops'] as List<dynamic>?)
              ?.map((e) => AirdropItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      alphaCheckins: (json['alpha_checkins'] as List<dynamic>?)
              ?.map((e) => AlphaCheckin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastRolloverDate: _parseString(json['last_rollover_date']) ?? '',
      top3Tokens: (json['top3_tokens'] as List<dynamic>?)
              ?.map((e) => TopToken.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bnbPriceUsd: _parseDouble(json['bnb_price_usd']) ?? 0,
      bnbPriceTs: _parseInt(json['bnb_price_ts']) ?? 0,
      bnbPriceSource: _parseString(json['bnb_price_source']) ?? '',
    );
  }
}

/// 历史数据响应
class HistoryResponse {
  final List<AirdropItem> airdrops;

  HistoryResponse({required this.airdrops});

  /// 按日期升序排序（旧日期在前，配合 ListView reverse: true 实现最新在最上）
  List<AirdropItem> get sortedAirdrops {
    final sorted = List<AirdropItem>.from(airdrops);
    sorted.sort((a, b) => a.compareDateTime(b));
    return sorted;
  }

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    return HistoryResponse(
      airdrops: (json['airdrops'] as List<dynamic>?)
              ?.map((e) => AirdropItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 价格查询响应
class PriceResponse {
  final bool success;
  final Map<String, PriceInfo> prices;
  final int timestamp;

  PriceResponse({
    required this.success,
    required this.prices,
    required this.timestamp,
  });

  factory PriceResponse.fromJson(Map<String, dynamic> json) {
    final rawPrices = json['prices'] as Map<String, dynamic>? ?? {};
    final prices = <String, PriceInfo>{};
    rawPrices.forEach((key, value) {
      prices[key] = PriceInfo.fromJson(value as Map<String, dynamic>);
    });
    return PriceResponse(
      success: json['success'] as bool? ?? false,
      prices: prices,
      timestamp: _parseInt(json['timestamp']) ?? 0,
    );
  }
}

class PriceInfo {
  final String token;
  final double dexPrice;
  final double price;

  PriceInfo({
    required this.token,
    required this.dexPrice,
    required this.price,
  });

  /// 显示价格，优先 dex_price
  String get displayPrice {
    if (dexPrice > 0) return '\$${dexPrice.toStringAsFixed(4)}';
    if (price > 0) return '\$${price.toStringAsFixed(4)}';
    return '';
  }

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    return PriceInfo(
      token: _parseString(json['token']) ?? '',
      dexPrice: (json['dex_price'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 格式化数字，添加千分位逗号
String _formatNumber(dynamic value) {
  if (value == null) return '-';
  final n = num.tryParse(value.toString());
  if (n == null) return value.toString();
  final parts = n.toString().split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.join('.');
}

/// 安全解析 String，支持 String / int / double 混用
String? _parseString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// 安全解析 int，支持 int / String 混用
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// 安全解析 double，支持 double / int / String 混用
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// 安全解析 bool，支持 bool / String 混用
bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true' || value == '1') return true;
    if (value == 'false' || value == '0') return false;
  }
  if (value is int) return value == 1;
  return null;
}
