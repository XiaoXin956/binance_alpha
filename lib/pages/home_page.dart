import 'dart:async';
import 'package:flutter/material.dart';
import '../models/data_model.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  DataResponse? _data;
  Map<String, PriceInfo> _prices = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String _today = '';
  Timer? _refreshTimer;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _today = _getTodayDate();
    _loadData();
    // 每100秒自动刷新
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _today = _getTodayDate();
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    if (!_isLoading) {
      setState(() => _isRefreshing = true);
      _spinController.repeat();
    }
    try {
      // 并发请求两个接口
      final results = await Future.wait([
        ApiService.fetchData(),
        ApiService.fetchPrices(),
      ]);
      final data = results[0] as DataResponse;
      final priceResp = results[1] as PriceResponse;
      if (mounted) {
        setState(() {
          _data = data;
          _prices = priceResp.prices;
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
        _spinController.stop();
        // 推送数据到桌面小部件
        WidgetService.updateWidget(data, _today);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _error = e.toString();
        });
        _spinController.stop();
      }
    }
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
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }

    // 只显示当天及之后的数据
    final allAirdrops = _data?.airdrops ?? [];
    final airdrops = allAirdrops.where((a) {
      if (a.date.isEmpty) return true; // 无日期的保留
      return a.date.compareTo(_today) >= 0;
    }).toList();
    final topTokens = _data?.top3Tokens ?? [];
    final bnbPrice = _data?.bnbPriceUsd ?? 0;
    final todayCheckin = _data?.alphaCheckins
        ?.where((c) => c.key == 'today')
        .firstOrNull
        ?.count;

    return Column(
      children: [
        // --- BNB 价格 & 签到数 Header ---
        if (bnbPrice > 0 || todayCheckin != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                if (bnbPrice > 0)
                  Chip(
                    avatar: const Icon(Icons.monetization_on, size: 16),
                    label: Text(
                      'BNB \$${bnbPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (bnbPrice > 0 && todayCheckin != null)
                  const SizedBox(width: 8),
                if (todayCheckin != null)
                  Chip(
                    avatar: const Icon(Icons.people, size: 16),
                    label: Text(
                      '今日签到: ${_formatNumber(todayCheckin)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                // 右上角刷新动画
                if (_isRefreshing)
                  RotationTransition(
                    turns: _spinController,
                    child: Icon(
                      Icons.autorenew,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
          ),

        // --- 空投列表 ---
        Expanded(
          child: airdrops.isEmpty
              ? const Center(child: Text('暂无数据'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: airdrops.length,
                    itemBuilder: (context, index) =>
                        _AirdropCard(item: airdrops[index], prices: _prices),
                  ),
                ),
        ),

        // --- Top 3 底部固定栏 ---
        if (topTokens.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '🔥 Top 3 热门',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...topTokens.map((t) => _TopTokenRow(token: t)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 空投卡片
class _AirdropCard extends StatelessWidget {
  final AirdropItem item;
  final Map<String, PriceInfo> prices;
  const _AirdropCard({required this.item, required this.prices});

  Color _statusColor() {
    switch (item.status) {
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

  @override
  Widget build(BuildContext context) {
    if (item.isWarning) {
      return _WarningCard(item: item, prices: prices, statusColor: _statusColor);
    }
    return _GrabCard(item: item, prices: prices, statusColor: _statusColor);
  }
}

/// 普通抢购卡片
class _GrabCard extends StatelessWidget {
  final AirdropItem item;
  final Map<String, PriceInfo> prices;
  final Color Function() statusColor;
  const _GrabCard({required this.item, required this.prices, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = prices[item.token];
    final totalPrice = _calcTotalPrice(price, item.amount);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.token,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (totalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          totalPrice,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                        icon: Icons.security,
                        label: '积分 ${item.points}',
                      ),
                      _InfoChip(
                        icon: Icons.access_time,
                        label: item.time,
                      ),
                      if (item.amount.isNotEmpty)
                        _InfoChip(
                          icon: Icons.inventory_2,
                          label: '数量 ${_formatNumber(item.amount)}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预警卡片
class _WarningCard extends StatelessWidget {
  final AirdropItem item;
  final Map<String, PriceInfo> prices;
  final Color Function() statusColor;
  const _WarningCard({required this.item, required this.prices, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = prices[item.token];
    final totalPrice = _calcTotalPrice(price, item.amount);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标 + 项目名 + 价格 + 标签
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  child: const Icon(Icons.warning_amber_rounded,
                      size: 22, color: Colors.red),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (totalPrice != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              totalPrice,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
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
                // 预警标签
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '预警',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 关键数据行：积分、时间、数量
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _WarningDetail(label: '积分', value: '${item.points}'),
                _WarningDetail(label: '时间', value: '${item.date} ${item.time}'),
                if (item.amount.isNotEmpty)
                  _WarningDetail(label: '数量', value: _formatNumber(item.amount)),
                if (item.totalAmount != null && item.totalAmount!.isNotEmpty)
                  _WarningDetail(label: '总量', value: _formatNumber(item.totalAmount!)),
              ],
            ),
            const SizedBox(height: 8),

            // 合约 + 链
            if (item.contractAddress != null || item.chainId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (item.chainId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Chain ${item.chainId}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    if (item.chainId != null &&
                        item.contractAddress != null)
                      const SizedBox(width: 8),
                    if (item.contractAddress != null &&
                        item.contractAddress!.isNotEmpty)
                      Flexible(
                        child: Text(
                          'CA: ${item.contractAddress!.substring(0, 6)}...${item.contractAddress!.substring(item.contractAddress!.length - 4)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

            // 交易哈希
            if (item.txHash != null && item.txHash!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Tx: ${item.txHash!.substring(0, 10)}...${item.txHash!.substring(item.txHash!.length - 6)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.outline,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // 底部：确认时间 + 状态
            Row(
              children: [
                if (item.confirmedAt != null)
                  _InfoChip(
                    icon: Icons.verified,
                    label: item.confirmedAt!,
                  ),
                if (item.confirmedAt != null) const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor(),
                    ),
                  ),
                ),
                if (item.futuresListed)
                  const Spacer(),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 预警详细信息行
class _WarningDetail extends StatelessWidget {
  final String label;
  final String value;
  const _WarningDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// Top 3 代币行
class _TopTokenRow extends StatelessWidget {
  final TopToken token;
  const _TopTokenRow({required this.token});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              token.symbol,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '买入: ${token.formattedTrades}次',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            '平均: \$${token.formattedAvgBuy}',
            style: const TextStyle(fontSize: 12),
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

/// 计算总价值：dex_price × amount，返回格式化金额字符串
/// 如果 amount 为空或无价格数据，返回 null
String? _calcTotalPrice(PriceInfo? price, String amount) {
  if (price == null) return null;
  if (amount.isEmpty) {
    // 没有数量时回退显示单价
    return price.displayPrice.isNotEmpty ? price.displayPrice : null;
  }
  final amt = num.tryParse(amount);
  if (amt == null || amt <= 0) return price.displayPrice.isNotEmpty ? price.displayPrice : null;

  final total = price.dexPrice * amt.toDouble();
  if (total <= 0) return null;

  if (total >= 10000) {
    return '\$${_formatNumber(total.toInt())}';
  } else if (total >= 1) {
    return '\$${total.toStringAsFixed(2)}';
  } else {
    return '\$${total.toStringAsFixed(6)}';
  }
}
