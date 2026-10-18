import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/offline_repository.dart';
import '../domain/offline_models.dart';
import '../domain/statistics.dart';
import 'offline_app.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.repository,
    required this.onSelectDay,
  });
  final OfflineRepository repository;
  final ValueChanged<DateTime> onSelectDay;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  StatsPeriod _period = StatsPeriod.week;
  DateTime _date = calendarDay(DateTime.now());

  void _move(int step) => setState(() {
    _date = switch (_period) {
      StatsPeriod.day => DateTime(_date.year, _date.month, _date.day + step),
      StatsPeriod.week => DateTime(
        _date.year,
        _date.month,
        _date.day + step * 7,
      ),
      StatsPeriod.month => DateTime(_date.year, _date.month + step),
    };
  });

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: calendarDay(DateTime.now()),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) {
    final summary = summarize(widget.repository.state, _date, _period);
    final today = calendarDay(DateTime.now());
    final endInclusive = DateTime(
      summary.end.year,
      summary.end.month,
      summary.end.day - 1,
    );
    final label = switch (_period) {
      StatsPeriod.day => dayKey(_date),
      StatsPeriod.week => '${dayKey(summary.start)} — ${dayKey(endInclusive)}',
      StatsPeriod.month => '${_date.year}年${_date.month}月',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        identified(
          'statistics-period',
          SegmentedButton<StatsPeriod>(
            segments: const [
              ButtonSegment(value: StatsPeriod.day, label: Text('每日')),
              ButtonSegment(value: StatsPeriod.week, label: Text('每周')),
              ButtonSegment(value: StatsPeriod.month, label: Text('每月')),
            ],
            selected: {_period},
            onSelectionChanged: (values) =>
                setState(() => _period = values.first),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            identified(
              'statistics-previous',
              IconButton(
                onPressed: summary.start.isAfter(DateTime(2000))
                    ? () => _move(-1)
                    : null,
                tooltip: '上一个周期',
                icon: const Icon(Icons.chevron_left),
              ),
            ),
            Expanded(
              child: identified(
                'statistics-date',
                TextButton(
                  onPressed: _chooseDate,
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                container: true,
              ),
            ),
            identified(
              'statistics-next',
              IconButton(
                onPressed: summary.end.isAfter(today) ? null : () => _move(1),
                tooltip: '下一个周期',
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已记录总摄入', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(
                      number(summary.totalIntake),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: leaf,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('千卡'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _summaryLine(
                  '完整日的日均摄入',
                  summary.averageIntake == null
                      ? '暂无完整记录'
                      : '${number(summary.averageIntake!)} 千卡',
                ),
                const SizedBox(height: 12),
                _summaryLine('已记录运动消耗', '${number(summary.totalExercise)} 千卡'),
                const SizedBox(height: 12),
                _summaryLine(
                  '完整记录',
                  '${summary.completeCount} / ${summary.days.length} 天',
                ),
                const SizedBox(height: 12),
                _summaryLine('有饮食记录', '${summary.recordedCount} 天'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '每日摄入',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  '点击某天查看明细 · 横向滑动查看更多日期',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _chart(summary.days),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('● 完整记录', style: TextStyle(color: leaf, fontSize: 11)),
                    Text(
                      '● 记录未完整',
                      style: TextStyle(color: Color(0xFFC5A15A), fontSize: 11),
                    ),
                    Text(
                      '— 未记录',
                      style: TextStyle(color: Colors.black38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '总量包含所有已记录摄入。日均只使用标记完整的日期及其摄入量；未记录不等于零摄入，未来日期不参与统计。',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (_period == StatsPeriod.day) ...[
          const SizedBox(height: 18),
          identified(
            'statistics-open-day',
            OutlinedButton.icon(
              onPressed: () => widget.onSelectDay(_date),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('查看当天三餐明细'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryLine(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _chart(List<DaySummary> days) {
    final maximum = days.fold<double>(
      1,
      (value, day) => math.max(value, day.intake),
    );
    return identified(
      'statistics-chart',
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in days)
              SizedBox(
                width: days.length > 14 ? 44 : 48,
                child: InkWell(
                  onTap: () => widget.onSelectDay(day.date),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 22,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            day.recorded || day.complete
                                ? number(day.intake)
                                : '—',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 120,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 22,
                            height: day.recorded || day.complete
                                ? math.max(3, day.intake / maximum * 120)
                                : 3,
                            decoration: BoxDecoration(
                              color: day.complete
                                  ? leaf
                                  : day.recorded
                                  ? const Color(0xFFC5A15A)
                                  : const Color(0xFFDDE2DA),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${day.date.day}日',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
