import 'package:flutter/material.dart';

import '../data/offline_repository.dart';
import '../domain/offline_models.dart';
import 'offline_app.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.repository});
  final OfflineRepository repository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _age = TextEditingController(
    text: widget.repository.state.profile?.age.toString() ?? '',
  );
  late final _height = TextEditingController(
    text: widget.repository.state.profile == null
        ? ''
        : number(widget.repository.state.profile!.height),
  );
  late final _weight = TextEditingController(
    text: widget.repository.state.profile == null
        ? ''
        : number(widget.repository.state.profile!.weight),
  );
  late bool? _male = widget.repository.state.profile?.male;
  bool _saving = false;
  bool _changed = false;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  String? _validate(
    String? text,
    double low,
    double high, {
    bool integer = false,
  }) {
    final value = double.tryParse(text?.trim() ?? '');
    if (value == null ||
        !value.isFinite ||
        value < low ||
        value > high ||
        (integer && int.tryParse(text?.trim() ?? '') == null)) {
      return '请输入${number(low)}—${number(high)}${integer ? '之间的整数' : '之间的数值'}';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_male == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择公式所用的性别参考')));
      return;
    }
    setState(() => _saving = true);
    final profile = BodyProfile(
      male: _male!,
      age: int.parse(_age.text.trim()),
      height: double.parse(_height.text.trim()),
      weight: double.parse(_weight.text.trim()),
    );
    final saved = await persistAction(
      context,
      () => widget.repository.saveProfile(profile),
      message: '身体资料已保存',
    );
    if (mounted) {
      setState(() {
        _saving = false;
        if (saved) _changed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.repository.state.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '身体资料',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  '资料保存在本机，用于估算静息能量消耗。',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _form,
                  onChanged: () => setState(() => _changed = true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('公式所用性别参考', style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      identified(
                        'profile-sex',
                        SegmentedButton<bool>(
                          emptySelectionAllowed: true,
                          segments: const [
                            ButtonSegment(value: true, label: Text('男性')),
                            ButtonSegment(value: false, label: Text('女性')),
                          ],
                          selected: {?_male},
                          onSelectionChanged: (values) => setState(() {
                            _male = values.isEmpty ? null : values.first;
                            _changed = true;
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      identified(
                        'profile-age',
                        TextFormField(
                          controller: _age,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '年龄（周岁）',
                            suffixText: '岁',
                          ),
                          validator: (text) =>
                              _validate(text, 19, 78, integer: true),
                        ),
                      ),
                      const SizedBox(height: 14),
                      identified(
                        'profile-height',
                        TextFormField(
                          controller: _height,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '身高',
                            suffixText: '厘米',
                          ),
                          validator: (text) => _validate(text, 100, 250),
                        ),
                      ),
                      const SizedBox(height: 14),
                      identified(
                        'profile-weight',
                        TextFormField(
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '体重',
                            suffixText: '公斤',
                          ),
                          validator: (text) => _validate(text, 25, 350),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: identified(
                          'profile-save',
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                              _saving
                                  ? '保存中…'
                                  : _changed
                                  ? '保存修改'
                                  : '保存资料',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '基础代谢估算',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  profile == null
                      ? '填写资料后显示'
                      : '${number(profile.restingCalories)} 千卡 / 天',
                  style: const TextStyle(
                    fontSize: 26,
                    color: leaf,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '采用 Mifflin–St Jeor 静息能量公式（REE）：\n'
                  '10 × 体重kg + 6.25 × 身高cm − 5 × 年龄\n'
                  '男性参考 +5，女性参考 −161。\n\n'
                  '原研究样本为19—78岁成年人。结果是估算值，不是实测基础代谢，也不等于每天总消耗。年龄由你手动更新。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: identified(
            'profile-sources',
            ListTile(
              leading: const Icon(Icons.info_outline, color: leaf),
              title: const Text('食物数据、隐私与开源说明'),
              subtitle: Text('当前本地食物 ${widget.repository.foods.length} 项'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSources,
            ),
          ),
        ),
      ],
    );
  }

  void _showSources() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '关于$offlineAppName',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            offlineAppSubtitle,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const SelectableText(
            '基于 OpenNutriTracker v2.4.0 定制，应用代码按 GPLv3 开源。\n'
            'https://github.com/simonoppowa/OpenNutriTracker\n\n'
            '数据完全存放本机，核心功能无需联网、账号或服务器。卸载应用或清除应用数据会删除本地记录。\n\n'
            '基础食物来源：USDA FoodData Central，SR Legacy 2018，CC0 1.0。'
            '中文名称为对应条目翻译或带说明的近似映射。\n'
            'https://fdc.nal.usda.gov/\n\n'
            '粤菜参考配方：本项目编写的示例组合，使用上述食材数据及明确列出的熟制可食重进行估算；'
            '不是某家餐厅的实测结果，也没有把整份研究菜谱热量冒充每100克数据。'
            '每个条目的详情列明配料和近似项，用户可保存自己的热量值。\n\n'
            '基础代谢相关公式：Mifflin等，1990。\n'
            'https://pubmed.ncbi.nlm.nih.gov/2305711/\n\n'
            '统计中的“完整记录”由你确认，含估算克数也可计入完整日。日均只统计完整日，其他日期仍计入总摄入。',
            style: TextStyle(fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 18),
          identified(
            'profile-license',
            OutlinedButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: offlineAppName,
                applicationVersion: offlineAppVersion,
              ),
              child: const Text('第三方开源许可'),
            ),
          ),
        ],
      ),
    ),
  );
}
