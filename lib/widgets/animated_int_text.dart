import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnimatedIntText extends StatelessWidget {
  const AnimatedIntText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          NumberFormat.decimalPattern().format(animatedValue.round()),
          style: style,
        );
      },
    );
  }
}
