import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/data_model.dart';

class ApiService {
  static const String _baseUrl = 'https://alpha123.uk';
  static int _requestCount = 0;

  static Map<String, String> _headers() {
    _requestCount++;
    return {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/124.0.0.0 Safari/537.36',
      'Cache-Control': 'no-cache',
      'X-Request-Id': 'fa$_requestCount',
    };
  }

  /// 通用 GET 请求，遇 403 自动重试一次
  static Future<http.Response> _get(Uri uri) async {
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode == 403) {
      // 403 可能临时，等 1.5 秒重试一次
      await Future.delayed(const Duration(milliseconds: 1500));
      return await http.get(uri, headers: _headers());
    }

    return response;
  }

  /// 获取首页数据 (含空投列表 + top3_tokens + BNB 价格)
  static Future<DataResponse> fetchData() async {
    final response = await _get(
      Uri.parse('$_baseUrl/api/data?fresh=1'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DataResponse.fromJson(json);
    } else {
      throw Exception('加载首页数据失败 ($response.statusCode)');
    }
  }

  /// 获取历史数据
  static Future<HistoryResponse> fetchHistory() async {
    final response = await _get(
      Uri.parse('$_baseUrl/api/historydata'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HistoryResponse.fromJson(json);
    } else {
      throw Exception('加载历史数据失败 ($response.statusCode)');
    }
  }

  /// 获取批量代币价格（多策略重试）
  static Future<PriceResponse> fetchPrices() async {
    // 按顺序尝试多个 URL 和 header 组合
    final attempts = [
      // 1) 原样
      () => http.get(
            Uri.parse('$_baseUrl/api/price/?batch_dex=true'),
            headers: _headers(),
          ),
      // 2) 去掉 User-Agent，加 Referer
      () => http.get(
            Uri.parse('$_baseUrl/api/price/?batch_dex=true'),
            headers: {
              'Accept': 'application/json',
              'Referer': 'https://alpha123.uk/zh/history.html',
              'Origin': _baseUrl,
            },
          ),
      // 3) 去掉尾部斜杠
      () => http.get(
            Uri.parse('$_baseUrl/api/price?batch_dex=true'),
            headers: _headers(),
          ),
      // 4) 不带参数
      () => http.get(
            Uri.parse('$_baseUrl/api/price/'),
            headers: _headers(),
          ),
      // 5) 最小 headers
      () => http.get(
            Uri.parse('$_baseUrl/api/price/?batch_dex=true'),
            headers: {'Accept': 'application/json'},
          ),
      // 6) 无任何 header，原始 GET
      () => http.get(Uri.parse('$_baseUrl/api/price/?batch_dex=true')),
    ];

    http.Response? lastResponse;
    for (final attempt in attempts) {
      try {
        lastResponse = await attempt();
        if (lastResponse.statusCode == 200) {
          final json = jsonDecode(lastResponse.body) as Map<String, dynamic>;
          return PriceResponse.fromJson(json);
        }
      } catch (_) {
        // 网络异常继续试
      }

      // 每次间隔短时间再试
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final code = lastResponse?.statusCode ?? 0;
    throw Exception('加载价格数据失败 ($code)');
  }
}
