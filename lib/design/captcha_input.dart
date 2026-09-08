import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:celechron/utils/global.dart';

class ImageCodePortal {
  /// 异步显示弹窗，返回用户输入的字符串。若取消则返回 null。
  static Future<String?> show({
    required Uint8List imageBytes,
    required Future<Uint8List> Function() onRefresh,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    final Completer<String?> completer = Completer<String?>();

    await showCupertinoModalPopup(
      context: context,
      barrierDismissible: false, // 强制用户点击按钮
      builder: (context) => _CaptchaDialog(
        imageBytes: imageBytes,
        onRefresh: onRefresh,
        completer: completer,
      ),
    );

    if (!completer.isCompleted) {
      completer.complete(null);
    }

    return completer.future;
  }
}

class _CaptchaDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final Future<Uint8List> Function() onRefresh;
  final Completer<String?> completer;

  const _CaptchaDialog({
    required this.imageBytes,
    required this.onRefresh,
    required this.completer,
  });

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  late final TextEditingController _inputController;
  late Uint8List _currentImage;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _currentImage = widget.imageBytes;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final newImage = await widget.onRefresh();
      if (mounted) {
        setState(() {
          _currentImage = newImage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        width: double.infinity,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "安全验证",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // 图片展示与刷新
            Semantics(
              button: true,
              label: "验证码图片，点击刷新",
              child: GestureDetector(
                onTap: _refresh,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _currentImage,
                    height: 60,
                    width: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) =>
                        const Icon(CupertinoIcons.refresh_thick),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: "点击刷新验证码",
              child: GestureDetector(
                onTap: _refresh,
                child: const Text(
                  "点击图片刷新",
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 输入框
            CupertinoTextField(
              controller: _inputController,
              placeholder: "请输入验证码",
              autofocus: true,
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 10,
              ),
              textAlign: TextAlign.center,
              decoration: BoxDecoration(
                color: CupertinoColors.quaternarySystemFill,
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(height: 24),

            // 按钮组
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    child: const Text("取消"),
                    onPressed: () {
                      Navigator.pop(context);
                      if (!widget.completer.isCompleted) {
                        widget.completer.complete(null);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: CupertinoButton.filled(
                    padding: EdgeInsets.zero,
                    child: const Text("确定"),
                    onPressed: () {
                      final text = _inputController.text;
                      Navigator.pop(context);
                      if (!widget.completer.isCompleted) {
                        widget.completer.complete(text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
