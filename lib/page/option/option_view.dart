import 'package:celechron/utils/platform_features.dart';
import 'package:flutter/cupertino.dart';

import 'package:url_launcher/url_launcher_string.dart';

import 'package:celechron/utils/utils.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/design/cupertino_async_switch.dart';
import 'package:celechron/design/app_visual.dart';
import 'package:celechron/design/sub_title.dart';

import 'allow_time_edit_page.dart';
import 'course_id_mapping_edit_page.dart';
import 'credits_page.dart';
import 'diagnostic_log_page.dart';
import 'package:get/get.dart';
import 'custom_license_page.dart';
import 'login_page.dart';
import 'option_controller.dart';

class OptionPage extends StatelessWidget {
  final _optionController =
      Get.put(OptionController(), tag: 'optionController');

  OptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    var trailingTextStyle =
        TextStyle(color: AppVisual.secondaryLabel(context), fontSize: 16);

    var headerFooterTextStyle = CupertinoTheme.of(context)
        .textTheme
        .textStyle
        .merge(TextStyle(
            fontSize: 13.0, color: AppVisual.secondaryLabel(context)));

    return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        child: SafeArea(
            child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SubtitleRow(
                subtitle: '设置',
                padHorizontal: 16,
                padVertical: 8,
                fontSize: 32,
              ),
            ),
            // 教务
            Obx(() => SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    margin: _defaultMargin,
                    additionalDividerMargin: 2,
                    header: Container(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('教务', style: headerFooterTextStyle)),
                    footer: (_optionController.pushOnGradeChange ||
                                _optionController.pushOnDdlReminder) &&
                            _optionController.scholar.value.isLogan
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(
                                'Celechron 将不定期自动运行以刷新数据。请开启通知权限，且不要将 Celechron 从后台中移除。',
                                style: headerFooterTextStyle))
                        : null,
                    children: <CupertinoListTile>[
                      if (_optionController.scholar.value.isLogan) ...{
                        CupertinoListTile(
                            title: Text(
                                '已登录: ${_optionController.scholar.value.username}'),
                            trailing: BackChevronRow(
                                child: Text('退出',
                                    style: TextStyle(
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.systemRed, context),
                                        fontSize: 16))),
                            onTap: () async {
                              await showCupertinoDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return CupertinoAlertDialog(
                                      title: const Text('退出登录'),
                                      content: const Text('确定要退出当前账号吗？'),
                                      actions: [
                                        CupertinoDialogAction(
                                          child: const Text('取消'),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                          },
                                        ),
                                        CupertinoDialogAction(
                                          isDestructiveAction: true,
                                          child: const Text('退出'),
                                          onPressed: () async {
                                            Navigator.of(dialogContext).pop();
                                            await _optionController.logout();
                                          },
                                        ),
                                      ],
                                    );
                                  });
                            }),
                        CupertinoListTile(
                          title: const Text('重修绩点计算'),
                          trailing: CupertinoSlidingSegmentedControl(
                            children: {
                              GpaStrategy.first: Text('取首次',
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .copyWith(fontSize: 16)),
                              GpaStrategy.best: Text('取最高',
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .copyWith(fontSize: 16)),
                            },
                            groupValue: _optionController.gpaStrategy,
                            onValueChanged: (value) {
                              _optionController.gpaStrategy = value!;
                            },
                          ),
                        ),
                        CupertinoListTile(
                            title: const Text('隐藏绩点'),
                            trailing: Obx(() => CupertinoSwitch(
                                  activeTrackColor: AppVisual.brand,
                                  value: _optionController.hideHomeGpa,
                                  onChanged: (value) async {
                                    _optionController.hideHomeGpa = value;
                                  },
                                ))),
                        CupertinoListTile(
                          title: const Text('自定义课程代码映射'),
                          trailing: const BackChevronRow(),
                          onTap: () async {
                            Navigator.of(context, rootNavigator: true).push(
                                CupertinoPageRoute(
                                    builder: (context) =>
                                        CourseIdMappingEditPage()));
                          },
                        ),
                        CupertinoListTile(
                            title: const Text('刷新时逐项显示'),
                            subtitle: const Text('获取一项就显示一项'),
                            trailing: Obx(() => CupertinoSwitch(
                                  activeTrackColor: AppVisual.brand,
                                  value: _optionController.asyncRefresh,
                                  onChanged: (value) async {
                                    _optionController.asyncRefresh = value;
                                  },
                                ))),
                        CupertinoListTile(
                            title: const Text('推送成绩变动'),
                            trailing: CupertinoSwitch(
                              activeTrackColor: AppVisual.brand,
                              value: _optionController.pushOnGradeChange,
                              onChanged: PlatformFeatures.hasBackgroundRefresh
                                  ? (value) async {
                                      _optionController.pushOnGradeChange =
                                          value;
                                    }
                                  : null,
                            )),
                        CupertinoListTile(
                            title: const Text('推送作业截止提醒'),
                            trailing: CupertinoSwitch(
                              activeTrackColor: AppVisual.brand,
                              value: _optionController.pushOnDdlReminder,
                              onChanged: PlatformFeatures.hasBackgroundRefresh
                                  ? (value) async {
                                      _optionController.pushOnDdlReminder =
                                          value;
                                    }
                                  : null,
                            )),
                      } else ...{
                        CupertinoListTile(
                          title: const Text('点击登录',
                              style:
                                  TextStyle(color: CupertinoColors.activeBlue)),
                          trailing: const BackChevronRow(
                            child: Text(''),
                          ),
                          onTap: () async {
                            // Pop up a login widget from the bottom of the screen
                            showCupertinoModalPopup(
                                context: context,
                                builder: (BuildContext context) {
                                  return const LoginForm();
                                });
                          },
                        ),
                      },
                    ],
                  ),
                )),
            // 时间规划
            SliverToBoxAdapter(
                child: CupertinoListSection.insetGrouped(
                    additionalDividerMargin: 2,
                    margin: _defaultMargin,
                    header: Container(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('时间规划', style: headerFooterTextStyle)),
                    children: <CupertinoListTile>[
                  CupertinoListTile(
                    title: const Text('每次专注时长'),
                    trailing: BackChevronRow(
                        child: Obx(() => Text(
                            durationToString(_optionController.workTime),
                            style: TextStyle(
                                color: CupertinoDynamicColor.resolve(
                                    CupertinoColors.secondaryLabel, context),
                                fontSize: 16)))),
                    onTap: () async {
                      Duration newWorkTime = _optionController.workTime;
                      await showCupertinoDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return CupertinoAlertDialog(
                              title: const Text(
                                '每次专注时长',
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 200,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: CupertinoTimerPicker(
                                        mode: CupertinoTimerPickerMode.hm,
                                        minuteInterval: 5,
                                        initialTimerDuration: newWorkTime,
                                        onTimerDurationChanged: (value) {
                                          if (value >=
                                              const Duration(minutes: 5)) {
                                            newWorkTime = value;
                                          } else {
                                            newWorkTime =
                                                const Duration(minutes: 5);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('确定'),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                  },
                                )
                              ],
                            );
                          });
                      _optionController.workTime = newWorkTime;
                    },
                  ),
                  CupertinoListTile(
                    title: const Text('每次休息时长'),
                    trailing: BackChevronRow(
                        child: Obx(() => Text(
                            durationToString(_optionController.restTime),
                            style: trailingTextStyle))),
                    onTap: () async {
                      Duration newRestTime = _optionController.restTime;
                      await showCupertinoDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return CupertinoAlertDialog(
                              title: const Text(
                                '每次休息时长',
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 200,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: CupertinoTimerPicker(
                                        mode: CupertinoTimerPickerMode.hm,
                                        initialTimerDuration: newRestTime,
                                        onTimerDurationChanged: (value) {
                                          newRestTime = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('确定'),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                  },
                                )
                              ],
                            );
                          });
                      _optionController.restTime = newRestTime;
                    },
                  ),
                  CupertinoListTile(
                    title: const Text('可安排专注的时段'),
                    trailing: BackChevronRow(
                        child: Obx(() => Text(
                            '${_optionController.allowTimeLength} 个时段',
                            style: trailingTextStyle))),
                    onTap: () async {
                      await Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                        builder: (context) => const AllowTimeEditPage(),
                      ));
                    },
                  ),
                ])),
            // 日程
            Obx(() => SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                        additionalDividerMargin: 2,
                        margin: _defaultMargin,
                        header: Container(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text('日程', style: headerFooterTextStyle)),
                        children: [
                      CupertinoListTile(
                        title: const Text('同步到系统日历'),
                        trailing: CupertinoAsyncSwitch(
                          value: _optionController.calendarSyncEnabled &&
                              _optionController.hasCalendarPermission,
                          onChanged: (value) async {
                            await _optionController.toggleCalendarSync(
                                context, value);
                          },
                        ),
                      ),
                      CupertinoListTile(
                        title: Text(
                          '课表同步选项',
                          style: TextStyle(
                            color: _optionController.calendarSyncEnabled
                                ? null // 使用默认颜色
                                : CupertinoDynamicColor.resolve(
                                    CupertinoColors.quaternaryLabel, context),
                          ),
                        ),
                        trailing: BackChevronRow(
                            child: Text('选择学期',
                                style: TextStyle(
                                    color: CupertinoDynamicColor.resolve(
                                        CupertinoColors.secondaryLabel,
                                        context),
                                    fontSize: 16))),
                        onTap: _optionController.calendarSyncEnabled
                            ? () {
                                _optionController
                                    .showCalendarSyncDialog(context);
                              }
                            : null, // 禁用点击
                      ),
                      CupertinoListTile(
                        title: const Text('导出为iCal文件'),
                        trailing: const BackChevronRow(),
                        onTap: () =>
                            _optionController.showExportDialog(context),
                      ),
                    ]))),
            // 工具
            SliverToBoxAdapter(
                child: CupertinoListSection.insetGrouped(
                    additionalDividerMargin: 2,
                    margin: _defaultMargin,
                    header: Container(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('工具', style: headerFooterTextStyle)),
                    children: <Widget>[
                  CupertinoListTile(
                    title: const Text('暗色模式'),
                    trailing: BackChevronRow(
                        child: Obx(() => Text(
                              _optionController.brightnessMode ==
                                      BrightnessMode.system
                                  ? "跟随系统设置"
                                  : _optionController.brightnessMode ==
                                          BrightnessMode.light
                                      ? "亮色模式"
                                      : "暗色模式",
                              style: trailingTextStyle,
                            ))),
                    onTap: () => _showBrightnessPicker(context),
                  ),
                ])),
            // 关于
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                additionalDividerMargin: 2,
                margin: _defaultMargin,
                header: Container(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text('高级选项', style: headerFooterTextStyle),
                ),
                children: [
                  CupertinoListTile(
                    title: const Text('诊断日志'),
                    subtitle: const Text('排查刷新问题，导出前自动隐藏敏感信息'),
                    trailing: const BackChevronRow(),
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        CupertinoPageRoute(
                          builder: (context) => DiagnosticLogPage(
                            version: _optionController.celechronVersion,
                            buildNumber: _optionController.celechronBuildNumber,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // 关于
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                  additionalDividerMargin: 2,
                  margin: _defaultMargin,
                  header: Container(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('关于', style: headerFooterTextStyle)),
                  children: <CupertinoListTile>[
                    CupertinoListTile(
                      title: const Text('关于 Celechron'),
                      trailing: BackChevronRow(
                        child: Text(_optionController.celechronVersion,
                            style: trailingTextStyle),
                      ),
                      onTap: () async {
                        Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                                builder: (context) => CreditsPage(
                                    version:
                                        _optionController.celechronVersion)));
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('服务条款'),
                      trailing: const BackChevronRow(),
                      onTap: () async {
                        Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                                builder: (context) =>
                                    const CustomLicensePage()));
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('前往项目网站'),
                      trailing: BackChevronRow(
                        child: Obx(() {
                          if (_optionController.hasNewVersion) {
                            return Row(children: [
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: CupertinoColors.systemRed,
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              Text('有新版本可用', style: trailingTextStyle)
                            ]);
                          } else {
                            return const Text('');
                          }
                        }),
                      ),
                      onTap: () async {
                        await launchUrlString(
                          'https://github.com/Yuel25/Celechron-Next',
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ]),
            )
          ],
        )));
  }

  void _showBrightnessPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                _optionController.brightnessMode = BrightnessMode.system;
                Navigator.pop(context);
              },
              child: const Text('跟随系统设置'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                _optionController.brightnessMode = BrightnessMode.light;
                Navigator.pop(context);
              },
              child: const Text('亮色模式'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                _optionController.brightnessMode = BrightnessMode.dark;
                Navigator.pop(context);
              },
              child: const Text('暗色模式'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  static const _defaultMargin =
      EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 14.0);
}

class BackChevronRow extends StatelessWidget {
  final Widget? child;

  const BackChevronRow({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (child != null) child!,
      const SizedBox(width: 4),
      Icon(CupertinoIcons.chevron_forward,
          color: CupertinoDynamicColor.resolve(
              CupertinoColors.secondaryLabel, context),
          size: 16)
    ]);
  }
}
