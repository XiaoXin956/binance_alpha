import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/data_model.dart';

/// 桌面小部件数据推送服务
class WidgetService {
  static const _channel = MethodChannel('com.xiaoxin.binance_alpha/widget');

  /// 将首页数据推送到 Android 桌面小部件
  static Future<void> updateWidget(DataResponse data, String today) async {
    try {
      // 过滤当天及之后的数据
      final allAirdrops = data.airdrops.where((a) {
        if (a.date.isEmpty) return true;
        return a.date.compareTo(today) >= 0;
      }).toList();

      // 统计
      final grabCount = allAirdrops.where((a) => !a.isWarning).length;
      final warningCount = allAirdrops.where((a) => a.isWarning).length;

      // 签到数
      final todayCheckin = data.alphaCheckins
          ?.where((c) => c.key == 'today')
          .firstOrNull
          ?.count;

      // 最新 3 条空投
      final latestAirdrops = allAirdrops.take(3).map((a) => {
            'token': a.token,
            'name': a.name,
            'time': a.time,
            'points': '${a.points}',
            'type': a.type,
          }).toList();

      // Top 3
      final top3 = data.top3Tokens.map((t) => {
            'symbol': t.symbol,
            'trades': t.trades ?? 0,
            'avgBuy': t.formattedAvgBuy,
          }).toList();

      final payload = jsonEncode({
        'bnb_price': data.bnbPriceUsd,
        'today_checkin': todayCheckin ?? 0,
        'today_airdrop_count': grabCount,
        'warning_count': warningCount,
        'latest_airdrops': latestAirdrops,
        'top3': top3,
      });

      await _channel.invokeMethod('updateWidget', {'data': payload});
    } catch (_) {
      // 静默失败（可能是非 Android 平台）
    }
  }
}
