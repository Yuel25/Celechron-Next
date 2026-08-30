# Celechron

<div style="text-align: center; ">

<img src="./banner.png" style="width: 80%;">

**服务于浙大学生的时间管理器**

[![Release](https://img.shields.io/github/v/release/Yuel25/Celechron-Next?display_name=tag)](https://github.com/Yuel25/Celechron-Next/releases)
[![License](https://img.shields.io/github/license/Yuel25/Celechron-Next)](LICENSE)

日程一览 · 课表查看 · DDL 助手 · 成绩查询

</div>

## 简介

Celechron 是一款为浙江大学学生打造的时间管理 App:课表、考试、日程、待办与校园卡整合进同一条时间线,帮你安排好每一天。本仓库为其 Android 平台的延续版本,基于 Flutter 构建,采用 iOS 原生(Cupertino)视觉风格。

## 功能特性

### 🕐 接下来

- 时间线展示接下来的课程、考试与日程,临近事项一目了然
- 时间规划:设定目标后自动拆分为工作段与休息段,按规划开始专注

### 📅 日程

- 月 / 周视图日历,标注考试周与假期
- 自由添加、编辑个人日程
- 可将课表与日程同步到系统日历,或导出为 iCal 文件供其他日历应用使用

### ✅ 任务

- DDL 助手:按待办 / 已完成 / 已过期管理任务
- 支持批量清理已完成与已过期任务
- 配合通知推送作业截止提醒

### 🎓 学业

- 课表:登录教务系统后自动导入,支持自定义课程代码映射
- 成绩:四分制 / 五分制 / 百分制换算,主修均绩与学分统计,支持重修绩点计算与隐藏绩点
- 考试安排查询,成绩变动推送

### 🎫 校园卡

- 应用内查看校园卡余额与付款码
- 桌面小组件,不打开 App 也能随时看到余额

### ⚙️ 更多

- 亮色 / 暗色 / 跟随系统主题
- 后台异步刷新,通知推送作业截止与成绩变动
- 诊断与测试:查看、复制或导出脱敏诊断日志
- 应用内更新检查,新版本及时提醒

## 下载安装

前往 [Releases](https://github.com/Yuel25/Celechron-Next/releases) 页面下载最新签名的 APK 直接安装,要求 **Android 9.0(API 28)及以上**。

## 从源码构建

环境要求:

- Flutter stable(CI 固定使用 3.47.2)
- JDK 17
- Android SDK

```bash
git clone https://github.com/Yuel25/Celechron-Next.git
cd Celechron-Next
flutter pub get
flutter test                  # 运行单元测试
flutter build apk --release
```

构建产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 技术栈

| 组件 | 用途 |
| --- | --- |
| [Flutter](https://flutter.dev) | UI 框架,Cupertino 视觉风格 |
| [GetX](https://pub.dev/packages/get) | 状态管理与依赖注入 |
| [Hive](https://pub.dev/packages/hive) | 本地数据存储 |
| [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) | 登录凭据等敏感信息安全存储 |
| [workmanager](https://pub.dev/packages/workmanager) + [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) | 后台刷新与通知推送 |

## 隐私说明

课表、成绩、日程等数据全部保存在你的设备本地;登录凭据存放于系统安全存储,仅用于与学校教务系统通信。应用支持导出脱敏的诊断日志,只有在你主动导出并分享时,日志才会离开设备。

## 免责声明

本项目为开源学生作品,与浙江大学官方无关,使用本项目产生的一切后果由使用者自行承担。

## 许可证

本项目基于 [GPL-3.0](LICENSE) 协议开源。

## 致谢

- [Celechron](https://github.com/Celechron/Celechron) — 本项目的上游原始版本
- 项目官网:[celechron.top](https://celechron.top)
