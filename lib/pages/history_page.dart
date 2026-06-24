import 'package:flutter/material.dart';
import '../models/data_model.dart';
import '../services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<AirdropItem>? _airdrops;
  Map<String, PriceInfo> _prices = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      // 并发请求历史 + 价格
      final results = await Future.wait([
        ApiService.fetchHistory(),
        ApiService.fetchPrices(),
      ]);
      final response = results[0] as HistoryResponse;
      final priceResp = results[1] as PriceResponse;
      if (mounted) {
        setState(() {
          _airdrops = response.sortedAirdrops; // 按日期降序
          _prices = priceResp.prices;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'announced':
        return Colors.green;
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      case 'upcoming':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
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

  String _formatMarketCap(double? value) {
    if (value == null) return '-';
    if (value >= 1e9) {
      return '\$${(value / 1e9).toStringAsFixed(2)}B';
    } else if (value >= 1e6) {
      return '\$${(value / 1e6).toStringAsFixed(2)}M';
    } else if (value >= 1e3) {
      return '\$${(value / 1e3).toStringAsFixed(2)}K';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadHistory, child: const Text('重试')),
          ],
        ),
      );
    }

    final airdrops = _airdrops ?? [];

    if (airdrops.isEmpty) {
      return const Center(child: Text('暂无历史数据'));
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: airdrops.length,
        itemBuilder: (context, index) => _HistoryCard(
          item: airdrops[index],
          prices: _prices,
          statusColor: _statusColor,
          statusText: _statusText,
          formatMarketCap: _formatMarketCap,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AirdropItem item;
  final Map<String, PriceInfo> prices;
  final Color Function(String) statusColor;
  final String Function(String) statusText;
  final String Function(double?) formatMarketCap;

  const _HistoryCard({
    required this.item,
    required this.prices,
    required this.statusColor,
    required this.statusText,
    required this.formatMarketCap,
  });

  /// 计算总价值：dex_price × amount
  String? _calcTotal(String amount) {
    if (amount.isEmpty || amount == '0') return null;
    final price = prices[item.token];
    if (price == null || price.dexPrice <= 0) return null;
    final amt = num.tryParse(amount);
    if (amt == null || amt <= 0) return null;
    final total = price.dexPrice * amt.toDouble();
    if (total >= 10000) {
      return '\$${_formatNumber(total.toInt())}';
    } else if (total >= 1) {
      return '\$${total.toStringAsFixed(2)}';
    } else {
      return '\$${total.toStringAsFixed(6)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：项目名 + 状态
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    item.shortName.isNotEmpty
                        ? item.shortName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.token.isNotEmpty && item.name.isNotEmpty)
                        Text(
                          item.token,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor(item.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText(item.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor(item.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 日期 & 时间
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  item.date,
                  style: TextStyle(
                      fontSize: 13, color: theme.colorScheme.outline),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  item.time,
                  style: TextStyle(
                      fontSize: 13, color: theme.colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 积分 & 金额
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _DetailChip(
                  label: '积分门槛',
                  value: "${item.points}",
                  theme: theme,
                ),
                if (item.amount.isNotEmpty && item.amount != '0')
                  _DetailChip(
                    label: '金额',
                    value: _calcTotal(item.amount) ?? '${_formatNumber(item.amount)}',
                    theme: theme,
                  ),
                if (item.marketCap != null)
                  _DetailChip(
                    label: '市值',
                    value: formatMarketCap(item.marketCap),
                    theme: theme,
                  ),
                if (item.fdv != null)
                  _DetailChip(
                    label: 'FDV',
                    value: formatMarketCap(item.fdv),
                    theme: theme,
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // 底部信息：合约地址、链、交易对状态
            Row(
              children: [
                if (item.chainId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Chain ${item.chainId}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                if (item.chainId != null) const SizedBox(width: 6),
                if (item.spotListed == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '现货',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ),
                if (item.futuresListed)
                  const SizedBox(width: 6),
                if (item.futuresListed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '合约',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                if (item.contractAddress != null &&
                    item.contractAddress!.isNotEmpty)
                  const Spacer(),
                if (item.contractAddress != null &&
                    item.contractAddress!.isNotEmpty)
                  Flexible(
                    child: Text(
                      'CA: ${item.contractAddress!.substring(0, 6)}...${item.contractAddress!.substring(item.contractAddress!.length - 4)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _DetailChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label: ',
        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// 格式化数字（千分位）
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
