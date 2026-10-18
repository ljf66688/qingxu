# 安卓热量软件候选核验：Waistline 与 Energize

核验基准：2026-10-15，Asia/Shanghai。只研究，不写软件代码、不安装、不构建。以下安装难度是根据官方构建说明推断，未在真机验证。

## 结论供主报告使用

- **Waistline 可直接试用，二次开发可复用的饮食功能很完整**：明确支持早餐/午餐等自定义餐次、食物克数、组合餐与菜谱、负数热量快捷记录运动。独立 BMR 页面未核实，因此不能说开箱即用满足全部要求。
- **Energize 不是全部需求的直接替代品**：有中文、克数记录、本地自定义食物、个人资料计算营养目标；源码确实计算 BMR 中间值，但界面及返回模型只给经活动系数和体重目标调整后的每日目标，未独立输出 BMR；未找到手填每日运动消耗模块。餐食按摄入时间自动分组，与用户明确选择早餐/午餐/晚餐也有差别。
- 两者均可下载成品 APK，无需为个人使用部署服务器；二次开发才需要 Android 构建环境。中国常见菜肴数据覆盖、境内外部查询稳定性和实机体验都还需试用，不能由“有中文”推断“有完整中餐库”。

## Waistline

### 仓库与维护

正确仓库是 [davidhealey/waistline](https://github.com/davidhealey/waistline)，不是 davidheal/waistline，后者返回 404。官方 [F-Droid 页面](https://f-droid.org/en/packages/com.waist.line/) 同样指向该仓库。

- 最新稳定版 **3.11.1，2026-08-15 16:20:52 UTC**（中国时间 8 月 16 日 00:20）。本次 GitHub connector `get_latest_release` 实时核验，资产包括 `waistline-release.apk` 和 AAB。此次修复与 Google 相机权限政策有关。[Release](https://github.com/davidhealey/waistline/releases/tag/3.11.1)
- 最新默认分支合并提交为 **2026-10-12**，`945fdd1af55b319e1123e7de31bded77222e8886`；同日实质提交 `bb4ef2a49fd5650ee3673e694bd5b21c7a4f6f3f` 重构运动抓取的日期生成。9 月还有边到边界面修复及日记界面调整。这些实际提交加上近期发布足以判断仍维护；不是按星数或 pushed_at 推断。[官方提交 Atom](https://github.com/davidhealey/waistline/commits/master.atom)、[实质提交](https://github.com/davidhealey/waistline/commit/bb4ef2a49fd5650ee3673e694bd5b21c7a4f6f3f)
- 官方仓库页面未显示归档提示；由于 GitHub API 限流，未取得 archived 布尔字段，不应将“未显示提示”写成 API 已确认。

### 功能与复用证据

[官方 FAQ](https://github.com/davidhealey/waistline/blob/master/FAQ.md) 明确说明：

| 用户需求 | 核验结果 |
|---|---|
| 早餐、午餐、晚餐 | 日记内有 Breakfast、Lunch 等分类，设置中可改名或新增分类。 |
| 各种食物克数 | 按食物营养数据的计量单位填写 serving size，例如每 100 g 数据、实际食用 60 g 就填 60；另有份数乘数。 |
| 自制菜/菜谱 | Meal 把成分分别加入日记；Recipe 把多个成分聚合成一条菜谱。可复用食材量、营养汇总和食物库。 |
| 手填运动 kcal | 日记长按加号快速填热量，运动用负数；程序会相应增加当天摄入目标。不是独立运动页面。 |
| 基础代谢 BMR | 本次官方 README/FAQ 未提供明确 BMR 估算器或独立结果证据，列为未核实，不能声称已支持。 |
| 中文 | 有 Crowdin 本地化体系；本次未完成实际中文语言包及界面覆盖率核验，列为未核实。 |
| 中餐数据库 | 未证明内置完整中国菜库；支持本地手建食物、菜谱和批量导入食品 JSON，可补授权数据。 |

上述功能可直接复用；若要用户体验更清晰，还需要把负数运动录入改成正数运动 kcal、独立展示摄入与消耗，并补 BMR 页面。FAQ 同时提醒，修改原食品会影响引用它的历史记录，历史数据策略应纳入二次开发评估。

### 安装和构建

- 用户直接从 [官方 Release](https://github.com/davidhealey/waistline/releases/tag/3.11.1) 或 [F-Droid](https://f-droid.org/en/packages/com.waist.line/) 安装 APK；F-Droid 收录 3.11.1 的日期为 2026-08-19，要求 Android 5.0+，约 12 MiB。
- [README](https://github.com/davidhealey/waistline/blob/master/README.md) 说明数据留在设备，联网只用于 Open Food Facts / USDA 查食物和上传；手动录食物不需要自建后端。USDA 集成是可选的。
- 技术栈 Cordova + Framework7 + JavaScript。[package.json](https://github.com/davidhealey/waistline/blob/master/package.json) 当前使用 Cordova 12、cordova-android 15.1；[config.xml](https://github.com/davidhealey/waistline/blob/master/config.xml) 的 minSdk 21、compile/targetSdk 36。
- [贡献指南](https://github.com/davidhealey/waistline/blob/master/CONTRIBUTING.md) 提供 Docker 或手动装依赖两条路径，核心步骤为 npm install、添加 browser/android 平台、cordova build android。浏览器调试比较方便，但相机、文件、旧条码扫描等原生插件仍需 Android 真机验证，不能把它当成无成本网页打包。
- 许可证 **GPLv3**，主代码许可与框架生成目录许可分别在 README 说明。[许可说明](https://github.com/davidhealey/waistline#license)

## Energize

### 仓库与维护

官方主仓库是 **[Codeberg epinez/Energize](https://codeberg.org/epinez/Energize)**，不是 GitHub 项目。这是额外候选，不应伪装成 GitHub 调研结果。

- Codeberg API 返回 `archived: false`。[仓库元数据 API](https://codeberg.org/api/v1/repos/epinez/Energize)
- 最新稳定版 **v0.14.0，2026-08-30**，中国时间 21:54，附 arm64-v8a、armeabi-v7a、x86_64 APK。[Release](https://codeberg.org/epinez/Energize/releases/tag/v0.14.0)、[发布 API](https://codeberg.org/api/v1/repos/epinez/Energize/releases?limit=3)
- 最新实质提交中国时间 **2026-10-10 05:07**，数据库管理面板重构；之前同一天有食物来源映射重构与 Swiss 数据库营养换算修复，说明近期仍有功能代码维护。[最新提交](https://codeberg.org/epinez/Energize/commit/c598a155d4373fcf20f8d106b706a3c7a01f61de)、[换算修复](https://codeberg.org/epinez/Energize/commit/20c706ce3918063b2cb2a8a2c50d741469edb179)

### 是否直接满足用户需求

| 用户需求 | 核验结果 |
|---|---|
| 克数与热量 | 支持。track_food_modal 明确有 g 单位、默认 100 g、可切换份数。[源码](https://codeberg.org/epinez/Energize/src/branch/main/lib/pages/tab_tracking/track_food_modal.dart) |
| 明确早中晚餐分类 | 官方功能是按时间自动分组 tracked food；分组显示 mealAt(time)，不能直接说等同手选三餐。[官方 Features](https://codeberg.org/epinez/Energize/wiki/Features)、[分组源码](https://codeberg.org/epinez/Energize/src/branch/main/lib/pages/tab_tracking/widgets/tracked_food_list_item_grouper.dart) |
| 性别/年龄/身高/体重 | 有，计算营养目标界面及计算器支持。[计算界面](https://codeberg.org/epinez/Energize/src/branch/main/lib/pages/tab_settings/personalization_page/widgets/calculation_tab/calculation_tab.dart) |
| BMR 独立显示 | **未见支持**。计算器内部按 Mifflin-St Jeor 算 BMR，然后乘 activityLevel 和 weightTarget，返回目标热量。输出类只有 calories、protein、carbs、fat；UI显示“计算的营养目标”。[计算器](https://codeberg.org/epinez/Energize/src/branch/main/lib/services/nutrition_targets_calculator/nutrition_targets_calculator.dart)、[输出模型](https://codeberg.org/epinez/Energize/src/branch/main/lib/services/nutrition_targets_calculator/calculated_nutrition_targets.dart) |
| 手填每日运动 kcal | **本次未找到**。官方功能清单没有，递归源码树没有运动记录页面/模型；activityLevel 是生活活动系数滑块，不是某次运动消耗。未安装实机，不能绝对断言所有隐藏路径均无此功能。[功能列表](https://codeberg.org/epinez/Energize/wiki/Features)、[源码树 API](https://codeberg.org/api/v1/repos/epinez/Energize/git/trees/main?recursive=1) |
| 中文 | 有。稳定 tag v0.14.0 的 app_zh.arb 有实际简体中文食物、个人资料等翻译；app_zh_Hans 另有文件。未验证完整翻译率及真机呈现。[稳定版中文文件](https://codeberg.org/epinez/Energize/src/tag/v0.14.0/lib/l10n/app_zh.arb) |
| 自定义食物/复用菜谱 | 自定义食物官方明确支持；未发现像 Waistline 一样可按配方食材生成菜谱的证据，不能把 custom food 当 recipe。[README](https://codeberg.org/epinez/Energize/src/branch/main/README.md) |

### 安装与二次开发

成品 APK 安装不需要自建后端；本地 SQLite 存食物与记录，查库可选 Open Food Facts、USDA 与 Swiss Food Composition Database。[官方功能](https://codeberg.org/epinez/Energize/wiki/Features)、[pubspec](https://codeberg.org/epinez/Energize/src/branch/main/pubspec.yaml)

开发使用 Flutter，官方要求使用仓库固定的 SDK、复制 `.env.example`，执行 flutter pub get、build_runner 类型生成、flutter build apk。`.env.example` 提示申请 USDA API Key；这影响 USDA 查库，不代表所有本地功能都必须联网。Web 版还限制条码扫描、Open Food Facts 与本地备份，因此不应把 Web demo 当 Android 完整功能。[BUILD.md](https://codeberg.org/epinez/Energize/src/branch/main/BUILD.md)、[环境变量示例](https://codeberg.org/epinez/Energize/src/branch/main/.env.example)

许可证是 **AGPLv3**。[LICENSE](https://codeberg.org/epinez/Energize/src/branch/main/LICENSE)。本笔记只记录声明，不作法律解释。

## 核验限制

GitHub 匿名 REST 与随后 connector 出现限流，通用 web 搜索也返回 429；采用官方 raw 文件、GitHub Atom、官方发布 connector、Codeberg 官方 API 与原始源码补核。已明确区分稳定版本与默认分支功能；除中文稳定 tag、发布资产外，多数源码核验来自主分支，可能尚未进入最新稳定 APK。所有日期均不晚于用户基准 2026-10-15，未采用未来发布日期。未执行构建或 APK 测试，未对中国食物覆盖作数量承诺。
