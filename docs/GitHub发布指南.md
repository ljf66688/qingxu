# 轻序 GitHub 发布与维护指南

目标仓库：[ljf66688/qingxu](https://github.com/ljf66688/qingxu)。分享范围：项目介绍、全部界面预览、完整源码。

## 第一次发布的步骤

| 步骤 | 操作位置与做法 | 完成标志 |
| --- | --- | --- |
| 1. 确认仓库 | GitHub右上角头像 → Your repositories → qingxu；这个仓库已存在，无需再点New repository | 页面地址为 `github.com/ljf66688/qingxu` |
| 2. 准备首页 | 本地根目录 `README.md`，填写实际功能、预览、进度与构建入口 | 打开README能看到“轻序 Qingxu”，没有把上游商店链接当成轻序下载链接 |
| 3. 保留署名与许可 | 根目录 `ATTRIBUTION.md`、`README.upstream.md`、`LICENSE` | 可找到Simon Oppowa、OpenNutriTracker链接和GPLv3全文 |
| 4. 排除私密文件 | 根目录 `.gitignore`；检查实际待提交清单 | 不包含`.env`、`env.g.dart`、`key.properties`、私钥、缓存、用户数据库和`outputs/`；`.env.example`只有占位值 |
| 5. 上传 | 将核验过的发布副本提交到目标仓库main分支 | Code页出现README、lib、assets、test、docs等源码文件，而非只有一个源码ZIP |
| 6. 检查结果 | GitHub的Code页滚动到README，点击全部预览、作者与来源 | 图片和文档可打开；提交记录可见首次发布 |
| 7. 检查可见性 | 仓库名称旁显示Public或Private；需要更改时在Settings → General → Danger Zone → Change repository visibility | Public表示公开；Private仅授权账号可见。公开前先完成文件检查 |

## 以后怎样改介绍

操作位置：仓库Code页 → README.md → 铅笔图标 → 修改文字 → Preview检查排版 → Commit changes。完成标志：返回首页后能看到新文字和新提交。

每次只改介绍可以在网页上完成。更新整套源码建议使用GitHub Desktop：File → Clone repository，选择 `ljf66688/qingxu`，本地路径用英文（例如 `C:\dev\qingxu`）；修改文件后在Changes检查清单 → Summary填写如 `docs: 更新项目介绍` → Commit to main → Push origin。完成标志：网页出现对应提交。不要把本地环境、签名或个人数据拖到网页上传；网页上传不能依赖本地`.gitignore`替你过滤。

## 许可证怎么选

本项目直接改编自GPLv3代码，最简单且符合现有来源的方案是**保留原GPLv3 LICENSE，衍生程序整体沿用GPLv3**。它允许免费或收费分发、修改和商用；分发时需要保留版权和许可声明、标明改动，并按许可证提供对应源码。以后发APK时应同时提供该APK对应版本的源码。

| 选项 | 对当前项目的含义 |
| --- | --- |
| GPLv3（本项目采用） | 适合希望别人使用、分享和继续开发，同时让分发的衍生版本继续开放源码 |
| MIT／Apache-2.0 | 可用于权利允许的独立原创项目；当前整个衍生程序不能单方面换成这些许可证，除非取得必要权利人的其他授权 |
| 不放许可证／仅学习禁止商用 | 不符合已复用GPL代码的分发要求；GPL本身允许商用，不能另加禁止商用限制 |
| 私有仓库 | 控制谁能查看，不等于更换许可证；保留已有版权和来源声明 |

食物数据、第三方依赖与素材还要分别遵守自己的许可，见 `ATTRIBUTION.md`。

参考：[GPLv3条款与概要](https://choosealicense.com/licenses/gpl-3.0/) · [GitHub许可证说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)

## 每次发布前检查

检查实际提交清单及内容，确认没有密码、访问令牌、签名文件、真实饮食/身体数据和本机个人目录。保留测试中明确的假数据和公开的原作者署名。如果真实密钥曾经上传，应先撤销或轮换密钥；只删除最新文件并不能移除Git历史中的旧内容。

本仓库首次发布不启用继承的上游工作流；参考文件在 `docs/upstream-workflows/`。无需设置Supabase、Sentry或商店凭据即可阅读源码和开发离线入口。
