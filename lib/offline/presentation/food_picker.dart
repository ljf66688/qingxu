import 'package:flutter/material.dart';

import '../data/offline_repository.dart';
import '../domain/offline_models.dart';
import 'offline_app.dart';

class FoodPicker extends StatefulWidget {
  const FoodPicker({
    super.key,
    required this.repository,
    required this.date,
    required this.slot,
    this.embeddedFavorites = false,
  });
  final OfflineRepository repository;
  final DateTime date;
  final MealSlot slot;
  final bool embeddedFavorites;

  @override
  State<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<FoodPicker> {
  final _search = TextEditingController();
  String _mode = '全部';
  String _category = '全部分类';
  late MealSlot _slot = widget.slot;
  OfflineRepository get repository => widget.repository;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(LocalFood food) => showFoodAmountSheet(
    context,
    repository,
    food: food,
    slot: _slot,
    date: widget.date,
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) {
      final available = repository.search(_search.text);
      final recent = repository.recentFoods.map((food) => food.id).toList();
      final visible = available
          .where(
            (food) =>
                (!widget.embeddedFavorites ||
                    repository.state.favorites.contains(food.id)) &&
                (_mode != '收藏' ||
                    repository.state.favorites.contains(food.id)) &&
                (_mode != '最近' || recent.contains(food.id)) &&
                (_category == '全部分类' || food.category == _category),
          )
          .toList();
      if (_mode == '最近') {
        visible.sort(
          (a, b) => recent.indexOf(a.id).compareTo(recent.indexOf(b.id)),
        );
      }
      final categories = {
        '全部分类',
        ...repository.foods.map((food) => food.category),
      };
      final body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embeddedFavorites) ...[
                  const Text(
                    '常吃的，留在手边',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '收藏食物后，下次重新填写克数即可。',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text('记录日期：${dayKey(widget.date)}'),
                  const SizedBox(height: 8),
                  identified(
                    'favorites-meal',
                    SegmentedButton<MealSlot>(
                      segments: [
                        for (final slot in MealSlot.values)
                          ButtonSegment(value: slot, label: Text(slot.label)),
                      ],
                      selected: {_slot},
                      onSelectionChanged: (values) =>
                          setState(() => _slot = values.first),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                identified(
                  'food-search',
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜索白切鸡、炒饭、芥兰…',
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : identified(
                              'food-search-clear',
                              IconButton(
                                tooltip: '清除搜索',
                                onPressed: () =>
                                    setState(() => _search.clear()),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (!widget.embeddedFavorites)
                      for (final mode in ['全部', '收藏', '最近'])
                        identified(
                          'food-filter-${['全部', '收藏', '最近'].indexOf(mode)}',
                          ChoiceChip(
                            label: Text(mode),
                            selected: _mode == mode,
                            onSelected: (_) => setState(() => _mode = mode),
                          ),
                        ),
                    identified(
                      'food-category',
                      DropdownButton<String>(
                        value: categories.contains(_category)
                            ? _category
                            : '全部分类',
                        items: [
                          for (final category in categories)
                            DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _category = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '每100克可食部分 · 配方热量为参考估算，可自行调整',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 44,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.embeddedFavorites ? '还没有匹配的收藏' : '没有找到对应食物',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '试试别名，或者添加自己的食物。',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 14),
                          identified(
                            'food-create-empty',
                            OutlinedButton.icon(
                              onPressed: () => _createFood(),
                              icon: const Icon(Icons.add),
                              label: const Text('自行添加食物'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : identified(
                    'food-results',
                    ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final food = visible[index];
                        final favorite = repository.state.favorites.contains(
                          food.id,
                        );
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              14,
                              6,
                              4,
                              6,
                            ),
                            onTap: () => _add(food),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEDF2E7),
                              child: Icon(
                                food.custom
                                    ? Icons.edit_note
                                    : Icons.rice_bowl_outlined,
                                color: leaf,
                                size: 23,
                              ),
                            ),
                            title: Text(
                              food.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${number(food.kcal100)} 千卡 / 100克'
                              '${food.referenceKcal100 != null ? ' · 已调整' : ''}',
                              style: const TextStyle(fontSize: 12, color: leaf),
                            ),
                            trailing: IconButton(
                              tooltip: favorite ? '取消收藏' : '收藏',
                              onPressed: () => persistAction(
                                context,
                                () => repository.toggleFavorite(food.id),
                              ),
                              icon: Icon(
                                favorite ? Icons.star : Icons.star_border,
                                color: favorite
                                    ? const Color(0xFFC28A25)
                                    : Colors.black38,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: SizedBox(
              width: double.infinity,
              child: identified(
                'food-create',
                OutlinedButton.icon(
                  onPressed: _createFood,
                  icon: const Icon(Icons.add),
                  label: const Text('搜不到？自行添加食物'),
                ),
              ),
            ),
          ),
        ],
      );
      return widget.embeddedFavorites
          ? body
          : Scaffold(
              appBar: AppBar(
                title: Text('${dayKey(widget.date)} · ${_slot.label}'),
                actions: [
                  identified(
                    'food-done',
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
              body: SafeArea(top: false, child: body),
            );
    },
  );

  Future<void> _createFood() async {
    final food = await showDialog<LocalFood>(
      context: context,
      builder: (_) =>
          CreateFoodDialog(repository: repository, initialName: _search.text),
    );
    if (food != null && mounted) await _add(food);
  }
}

Future<void> showFoodAmountSheet(
  BuildContext context,
  OfflineRepository repository, {
  required LocalFood food,
  required MealSlot slot,
  required DateTime date,
  FoodLog? editing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FoodAmountSheet(
    repository: repository,
    food: food,
    slot: slot,
    date: date,
    editing: editing,
  ),
);

class FoodAmountSheet extends StatefulWidget {
  const FoodAmountSheet({
    super.key,
    required this.repository,
    required this.food,
    required this.slot,
    required this.date,
    this.editing,
  });
  final OfflineRepository repository;
  final LocalFood food;
  final MealSlot slot;
  final DateTime date;
  final FoodLog? editing;

  @override
  State<FoodAmountSheet> createState() => _FoodAmountSheetState();
}

class _FoodAmountSheetState extends State<FoodAmountSheet> {
  late LocalFood _food = widget.food;
  late final _grams = TextEditingController(
    text: number(
      widget.editing?.grams ?? widget.repository.lastGrams(widget.food.id),
    ),
  );
  late bool _estimated = widget.editing?.estimated ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final grams = double.tryParse(_grams.text.trim());
    if (grams == null || !grams.isFinite || grams < 0.1 || grams > 10000) {
      setState(() => _error = '请输入0.1—10000克之间的数值');
      return;
    }
    setState(() => _saving = true);
    final editing = widget.editing;
    final saved = await persistAction(
      context,
      () => editing == null
          ? widget.repository.addFood(
              food: _food,
              grams: grams,
              slot: widget.slot,
              date: widget.date,
              estimated: _estimated,
            )
          : widget.repository.editLog(editing, grams, _estimated),
    );
    if (!mounted) return;
    if (saved) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            editing == null ? '已加入${widget.slot.label}，可继续添加' : '已更新这条记录',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _changeEnergy() async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          FoodEnergyDialog(repository: widget.repository, food: _food),
    );
    final updated = widget.repository.foodById(_food.id);
    if (updated != null && mounted) setState(() => _food = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条饮食记录？'),
        content: Text('${_food.name} · ${_grams.text}克'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final saved = await persistAction(
      context,
      () => widget.repository.deleteLog(widget.editing!.id),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grams = double.tryParse(_grams.text.trim());
    final valid =
        grams != null && grams.isFinite && grams >= 0.1 && grams <= 10000;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _food.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('${dayKey(widget.date)} · ${widget.slot.label}'),
          const SizedBox(height: 8),
          Text(
            '${number(_food.kcal100)} 千卡 / 100克',
            style: const TextStyle(fontSize: 18, color: leaf),
          ),
          if (_food.referenceKcal100 != null)
            Text(
              '原始参考：${number(_food.referenceKcal100!)} 千卡 / 100克',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          const SizedBox(height: 12),
          Text(
            _food.note,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          identified(
            'food-source-details',
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('数据来源与计量说明', style: TextStyle(fontSize: 13)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SelectableText(
                    _food.source,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          if (widget.editing == null)
            identified(
              'food-adjust-energy',
              TextButton.icon(
                onPressed: _saving ? null : _changeEnergy,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('调整我的每100克热量'),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '本条使用记录时的热量值，食物库调整不会改写它。',
                style: TextStyle(fontSize: 12, color: leaf),
              ),
            ),
          const SizedBox(height: 12),
          identified(
            'food-grams',
            TextField(
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: '实际食用克数',
                suffixText: '克',
                errorText: _error,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final amount in [50, 100, 150, 200])
                identified(
                  'food-grams-$amount',
                  ActionChip(
                    label: Text('$amount克'),
                    onPressed: () => setState(() {
                      _grams.text = '$amount';
                      _error = null;
                    }),
                  ),
                ),
            ],
          ),
          identified(
            'food-estimated',
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('克数是估算的'),
              subtitle: const Text('没有秤也可以记录，历史会保留估算标记。'),
              value: _estimated,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _estimated = value),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1E5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('本次摄入')),
                Text(
                  valid ? '${number(grams * _food.kcal100 / 100)} 千卡' : '—',
                  style: const TextStyle(
                    fontSize: 25,
                    color: leaf,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: identified(
              'food-save',
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _saving
                        ? '保存中…'
                        : widget.editing == null
                        ? '加入${widget.slot.label}'
                        : '保存修改',
                  ),
                ),
              ),
            ),
          ),
          if (widget.editing != null)
            SizedBox(
              width: double.infinity,
              child: identified(
                'food-delete',
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: const Text(
                    '删除这条记录',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CreateFoodDialog extends StatefulWidget {
  const CreateFoodDialog({
    super.key,
    required this.repository,
    this.initialName = '',
  });
  final OfflineRepository repository;
  final String initialName;

  @override
  State<CreateFoodDialog> createState() => _CreateFoodDialogState();
}

class _CreateFoodDialogState extends State<CreateFoodDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _energy = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _energy.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加我的食物'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            identified(
              'custom-food-name',
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '食物名称'),
                validator: (text) =>
                    text == null || text.trim().isEmpty ? '请填写名称' : null,
              ),
            ),
            const SizedBox(height: 12),
            identified(
              'custom-food-energy',
              TextFormField(
                controller: _energy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '每100克热量',
                  suffixText: '千卡',
                ),
                validator: energyValidator,
              ),
            ),
            const SizedBox(height: 12),
            identified(
              'custom-food-note',
              TextFormField(
                controller: _note,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: '来源或说明（选填）',
                  hintText: '例如包装标示、熟制去骨',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '包装若标注千焦，先除以4.184换算成千卡。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving
            ? null
            : () async {
                if (!_form.currentState!.validate()) return;
                setState(() => _saving = true);
                LocalFood? food;
                final saved = await persistAction(context, () async {
                  food = await widget.repository.createFood(
                    _name.text,
                    double.parse(_energy.text.trim()),
                    _note.text,
                  );
                });
                if (!context.mounted) return;
                if (saved) {
                  Navigator.pop(context, food);
                } else {
                  setState(() => _saving = false);
                }
              },
        child: Text(_saving ? '保存中…' : '保存'),
      ),
    ],
  );
}

String? energyValidator(String? text) {
  final value = double.tryParse(text?.trim() ?? '');
  return value == null || !value.isFinite || value < 0 || value > 1000
      ? '请输入0—1000之间的千卡数值'
      : null;
}

class FoodEnergyDialog extends StatefulWidget {
  const FoodEnergyDialog({
    super.key,
    required this.repository,
    required this.food,
  });
  final OfflineRepository repository;
  final LocalFood food;

  @override
  State<FoodEnergyDialog> createState() => _FoodEnergyDialogState();
}

class _FoodEnergyDialogState extends State<FoodEnergyDialog> {
  late final _controller = TextEditingController(
    text: number(widget.food.kcal100),
  );
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(bool restore) async {
    if (!restore && !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = await persistAction(
      context,
      () => widget.repository.setFoodEnergy(
        widget.food.id,
        restore ? null : double.parse(_controller.text.trim()),
      ),
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
    title: const Text('我的热量参考值'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('只影响以后新加的记录，历史记录保留原值。'),
          const SizedBox(height: 16),
          identified(
            'food-energy-value',
            TextFormField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '每100克热量',
                suffixText: '千卡',
              ),
              validator: energyValidator,
            ),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.food.referenceKcal100 != null)
        TextButton(
          onPressed: _saving ? null : () => _save(true),
          child: const Text('恢复参考值'),
        ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : () => _save(false),
        child: const Text('保存'),
      ),
    ],
  );
}
