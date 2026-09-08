import 'package:flutter/cupertino.dart';

/// 缓存的年龄是信息，不表示最近一次请求失败。
class DataUpdatedLabel extends StatelessWidget {
  const DataUpdatedLabel({super.key, required this.age});
  final Duration age;

  String get text {
    if (age.inMinutes > 10000000) return '尚未更新';
    if (age.inMinutes < 1) return '刚刚更新';
    if (age.inMinutes < 60) return '${age.inMinutes} 分钟前更新';
    if (age.inHours < 24) return '${age.inHours} 小时前更新';
    return '${age.inDays} 天前更新';
  }

  @override
  Widget build(BuildContext context) {
    final color =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    return Padding(
        padding: const EdgeInsets.only(left: 4, right: 12, top: 4, bottom: 4),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color)));
  }
}
