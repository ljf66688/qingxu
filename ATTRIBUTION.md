# 作者与来源

## 上游项目

- 项目：[OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker)
- 原作者：**Simon Oppowa（[@simonoppowa](https://github.com/simonoppowa)）**。
- 其他作者：[上游贡献者名单](https://github.com/simonoppowa/OpenNutriTracker/graphs/contributors)，以及源文件中保留的版权声明。
- 本工作区基于的版本：[v2.4.0](https://github.com/simonoppowa/OpenNutriTracker/tree/v2.4.0)。
- 原许可证：GNU GPL version 3，全文保留在根目录 [LICENSE](LICENSE)。
- 原项目说明保留在 [README.upstream.md](README.upstream.md)。

本仓库包含原版 Flutter 工程，而非全部独立原创。除框架和构建基础外，离线功能复用了 `MealEntity`、`MealNutrimentsEntity`、`IntakeEntity.totalKcal`、ID生成及受保护的AES密钥流程。上游源文件的版权和许可声明继续有效。

## 轻序的修改

中文离线衍生版本由 [@ljf66688](https://github.com/ljf66688) 维护。主要离线实现与更名于 **2026-10-16** 完成，本次仓库介绍、署名、发布排除规则及预览整理日期为 **2026-10-18**。

新增 `lib/offline_main.dart`、`lib/offline/`、`assets/offline/`、`test/offline/` 和 `tools/offline/`，并修改 Android offline 变体、资源声明和相关构建配置，实现三餐克数、粤式食物搜索收藏、静息能量估算、运动手填及日周月统计。轻序衍生程序整体继续按 GPLv3 提供，不代表上游官方发布。

上游 `.github/workflows/`、Dependabot 与赞助配置在发布副本中归档到 `docs/upstream-workflows/`，保留其内容供参考，避免自动向原项目看板或商店执行操作。原工作流不是轻序已配置的CI。

## 食物、依赖与素材

- 42项基础食物来自 USDA FoodData Central / SR Legacy，逐项FDC编号见 `assets/offline/usda_provenance.json`；来源与CC0说明见 [食物库说明](assets/offline/README.md)。
- 50项粤式／家常参考配方及中文标签为本项目编写，组成数据按CC0提供；数值为参考估算。
- 500道粤菜研究资料仅用于调研，没有直接转换为每100克食物条目；对应数据集及其CC BY 4.0说明见食物库文档。
- Dart/Flutter与原生第三方依赖分别遵循自身许可证；依赖列表见 `pubspec.yaml` / `pubspec.lock`，应用许可页面保留。
- 上游保留的图标、截图、示例图片及 Unsplash 署名不因本仓库更名而转为原创或CC0。相关说明继续保留于上游源码和 `lib/core/utils/demo/`。
- `docs/screenshots/qingxu/` 为轻序组件生成的示例界面，不包含真实用户日记。

轻序的维护者信息不替代上游作者的版权，也不改变第三方各自的许可。
