import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/offline_repository.dart';
import '../domain/offline_models.dart';
import 'food_picker.dart';
import 'profile_page.dart';
import 'statistics_page.dart';

const ink = Color(0xFF21382E);
const leaf = Color(0xFF27634A);
const canvas = Color(0xFFF7F8F3);
const offlineAppName = '轻序';
const offlineAppSubtitle = '饮食与热量记录';
const offlineAppVersion = '0.1.1';

ThemeData offlineTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: leaf),
  scaffoldBackgroundColor: canvas,
  appBarTheme: const AppBarTheme(
    backgroundColor: canvas,
    foregroundColor: ink,
    centerTitle: false,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF1F4EE),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFDCEBDD),
  ),
);

Widget identified(String id, Widget child, {bool container = false}) =>
    Semantics(identifier: id, container: container, child: child);

String number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

Future<bool> persistAction(
  BuildContext context,
  Future<void> Function() action, {
  String? message,
}) async {
  try {
    await action();
    if (context.mounted && message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能保存，请检查输入或存储空间后重试。原有记录已保留。')),
      );
    }
    return false;
  }
}

class CantoneseOfflineApp extends StatelessWidget {
  const CantoneseOfflineApp({super.key, required this.repository});
  final OfflineRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: offlineAppName,
    debugShowCheckedModeBanner: false,
    theme: offlineTheme(),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: OfflineHome(repository: repository),
  );
}

class OfflineHome extends StatefulWidget {
  const OfflineHome({super.key, required this.repository});
  final OfflineRepository repository;

  @override
  State<OfflineHome> createState() => _OfflineHomeState();
}

class _OfflineHomeState extends State<OfflineHome> {
  int _tab = 0;
  DateTime _date = calendarDay(DateTime.now());
  bool _marking = false;
  OfflineRepository get repository => widget.repository;

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: calendarDay(DateTime.now()),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _toggleComplete(bool complete) async {
    if (_marking) return;
    if (complete) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('当天饮食都记好了吗？'),
          content: const Text('确认当天吃过的食物都已记录。含估算克数也可以标记完整；完整日会参与周、月日均计算。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续补记'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('已记录完整'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() => _marking = true);
    await persistAction(context, () => repository.setComplete(_date, complete));
    if (mounted) setState(() => _marking = false);
  }

  void _addFood(MealSlot slot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FoodPicker(repository: repository, date: _date, slot: slot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        toolbarHeight: _tab == 0 ? 72 : null,
        title: _tab == 0
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offlineAppName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 3),
                  Text(
                    offlineAppSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              )
            : Text(
                ['轻序', '热量统计', '常吃收藏', '我的'][_tab],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: leaf),
                SizedBox(width: 6),
                Text('本地离线', style: TextStyle(fontSize: 12, color: leaf)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (_tab) {
          0 => _today(),
          1 => StatisticsPage(
            repository: repository,
            onSelectDay: (date) => setState(() {
              _date = date;
              _tab = 0;
            }),
          ),
          2 => FoodPicker(
            repository: repository,
            date: _date,
            slot: MealSlot.lunch,
            embeddedFavorites: true,
          ),
          _ => ProfilePage(repository: repository),
        },
      ),
      bottomNavigationBar: identified(
        'offline-navigation',
        NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: [
            Semantics(
              identifier: 'nav-today',
              child: const NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: '今日',
              ),
            ),
            Semantics(
              identifier: 'nav-statistics',
              child: const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: '统计',
              ),
            ),
            Semantics(
              identifier: 'nav-favorites',
              child: const NavigationDestination(
                icon: Icon(Icons.star_border),
                selectedIcon: Icon(Icons.star),
                label: '收藏',
              ),
            ),
            Semantics(
              identifier: 'nav-profile',
              child: const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '我的',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _today() {
    final logs = repository.logsFor(_date);
    final total = logs.fold<double>(0, (sum, log) => sum + log.calories);
    final complete = repository.state.completeDays.contains(dayKey(_date));
    final exercise = repository.state.exercise[dayKey(_date)];
    final profile = repository.state.profile;
    final today = calendarDay(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: [
        Row(
          children: [
            identified(
              'diary-previous-day',
              IconButton(
                tooltip: '前一天',
                onPressed: _date.isAfter(DateTime(2000))
                    ? () => setState(
                        () => _date = DateTime(
                          _date.year,
                          _date.month,
                          _date.day - 1,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ),
            Expanded(
              child: identified(
                'diary-date',
                TextButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    '${_date.month}月${_date.day}日 · ${['周一', '周二', '周三', '周四', '周五', '周六', '周日'][_date.weekday - 1]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                container: true,
              ),
            ),
            identified(
              'diary-next-day',
              IconButton(
                tooltip: '后一天',
                onPressed: _date.isBefore(today)
                    ? () => setState(
                        () => _date = DateTime(
                          _date.year,
                          _date.month,
                          _date.day + 1,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: leaf,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('当天已记录摄入', style: TextStyle(color: Color(0xFFD9E9DD))),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text(
                    number(total),
                    style: const TextStyle(
                      fontSize: 44,
                      height: 1.1,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text('千卡', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                complete ? '✓ 当天已记录完整' : '记录每一餐，慢慢了解自己的饮食',
                style: const TextStyle(color: Color(0xFFD9E9DD), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: _metricCard(
                  '基础代谢估算',
                  profile == null ? '待设置' : number(profile.restingCalories),
                  profile == null ? '填写身体资料' : '千卡 / 天',
                  Icons.spa_outlined,
                  () => setState(() => _tab = 3),
                ),
              ),
              SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: _metricCard(
                  '当天运动消耗',
                  exercise == null ? '待记录' : number(exercise),
                  '手动填写 · 千卡',
                  Icons.directions_run,
                  () => _editExercise(exercise),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final slot in MealSlot.values) ...[
          _mealCard(slot, logs.where((log) => log.slot == slot).toList()),
          const SizedBox(height: 14),
        ],
        identified(
          'diary-complete-day',
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: complete,
            onChanged: _marking ? null : _toggleComplete,
            title: const Text('当天已记录完整'),
            subtitle: const Text('完整日参与周、月日均；估算记录也可以计入。'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            '基础代谢与运动消耗分别展示，不代表全天总消耗或实际热量缺口。',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    String title,
    String value,
    String caption,
    IconData icon,
    VoidCallback onTap,
  ) => Card(
    child: identified(
      title == '基础代谢估算' ? 'diary-profile' : 'diary-exercise',
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: leaf, size: 22),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                caption,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _mealCard(MealSlot slot, List<FoodLog> logs) {
    final calories = logs.fold<double>(0, (sum, log) => sum + log.calories);
    final icon = switch (slot) {
      MealSlot.breakfast => Icons.wb_sunny_outlined,
      MealSlot.lunch => Icons.rice_bowl_outlined,
      MealSlot.dinner => Icons.nights_stay_outlined,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: leaf),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoSizeText(
                    slot.label,
                    minFontSize: 14,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${number(calories)} 千卡',
                  style: const TextStyle(color: leaf),
                ),
              ],
            ),
            if (logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  '还没记录，添加这餐吃过的食物吧',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
              )
            else
              identified(
                'diary-${slot.name}-items',
                Column(
                  children: [
                    for (final log in logs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => showFoodAmountSheet(
                          context,
                          repository,
                          food: log.food,
                          slot: log.slot,
                          date: _date,
                          editing: log,
                        ),
                        title: Text(
                          log.food.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${number(log.grams)} 克${log.estimated ? ' · 估算' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text('${number(log.calories)} 千卡'),
                      ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: identified(
                'diary-add-${slot.name}',
                OutlinedButton.icon(
                  onPressed: () => _addFood(slot),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加食物'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editExercise(double? current) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          ExerciseDialog(repository: repository, date: _date, current: current),
    );
  }
}

class ExerciseDialog extends StatefulWidget {
  const ExerciseDialog({
    super.key,
    required this.repository,
    required this.date,
    required this.current,
  });
  final OfflineRepository repository;
  final DateTime date;
  final double? current;

  @override
  State<ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<ExerciseDialog> {
  late final _controller = TextEditingController(
    text: widget.current == null ? '' : number(widget.current!),
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    if (_saving) return;
    final value = double.tryParse(_controller.text.trim());
    if (!clear &&
        (value == null || !value.isFinite || value < 0 || value > 20000)) {
      setState(() => _error = '请输入0—20000之间的千卡数值');
      return;
    }
    setState(() => _saving = true);
    final saved = await persistAction(
      context,
      () => widget.repository.setExercise(widget.date, clear ? null : value),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('当天运动消耗'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('填写手表或你已知的当天运动总消耗，保存会替换原数值。'),
        const SizedBox(height: 18),
        identified(
          'exercise-calories',
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '运动消耗',
              suffixText: '千卡',
              errorText: _error,
            ),
          ),
        ),
      ],
    ),
    actions: [
      if (widget.current != null)
        TextButton(
          onPressed: _saving ? null : () => _save(clear: true),
          child: const Text('清空'),
        ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中…' : '保存'),
      ),
    ],
  );
}
