import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_format.dart';

/// نافذة اختيار حجم الخط مرتبطة بـ [notifier] ودالة الحفظ [onChanged].
void showFontSizeSheet(
  BuildContext context, {
  required ValueNotifier<double> notifier,
  required ValueChanged<double> onChanged,
  required double min,
  required double max,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext c) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ValueListenableBuilder<double>(
            valueListenable: notifier,
            builder: (BuildContext c, double size, Widget? _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('حجم خط القراءة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'تصغير',
                        onPressed: () => onChanged(size - 2),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Expanded(
                        child: Slider(
                          min: min,
                          max: max,
                          divisions: (max - min).round(),
                          value: size.clamp(min, max).toDouble(),
                          onChanged: onChanged,
                        ),
                      ),
                      IconButton(
                        tooltip: 'تكبير',
                        onPressed: () => onChanged(size + 2),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  Text('الحجم: ${ArabicFormat.digits(size.round())}',
                      style: TextStyle(color: AppTheme.muted(context))),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
