import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/history_event_labels.dart';
import '../models/history_record.dart';
import '../services/bms_ble_service.dart';

class HistoryScreen extends StatefulWidget {
  final BmsBleService bleService;
  final AppLocalizations loc;

  const HistoryScreen({
    super.key,
    required this.bleService,
    required this.loc,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<HistoryRecord> _items = [];
  int _nextStart = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  /// 单次条数少一些可降低单帧长度，减轻 BLE 透传/默认 MTU 下大包重组压力
  static const int _pageSize = 16;

  AppLocalizations get loc => widget.loc;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !widget.bleService.isConnected) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batch = await widget.bleService.readHistoryPage(_nextStart, _pageSize);
      if (!mounted) return;
      setState(() {
        if (batch.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(batch);
          _nextStart += batch.length;
          if (batch.length < _pageSize) _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _hasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.historyTitle)),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text('${loc.historyFailed}: $_error'),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _hasMore = true;
                      _nextStart = 0;
                      _items.clear();
                    });
                    _loadMore();
                  },
                  child: Text(loc.sohRefresh),
                ),
              ],
            ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(child: Text(loc.historyEmpty))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: _loading
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: _loadMore,
                                    child: Text(loc.historyLoadMore),
                                  ),
                          ),
                        );
                      }
                      final r = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${loc.historyEventType}: ${historyEventDisplayName(r.eventType, chinese: loc.language == AppLanguage.zh)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${loc.historyVoltage}: ${r.totalVoltage.toStringAsFixed(1)} V',
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.historyCurrent}: ${r.current.toStringAsFixed(1)} A',
                                    ),
                                  ),
                                  Expanded(
                                    child: Text('${loc.historySoc}: ${r.soc}%'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
