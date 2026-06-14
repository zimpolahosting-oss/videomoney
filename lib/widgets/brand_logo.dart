import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 72,
    this.markOnly = false,
  });

  final double height;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      markOnly
          ? 'assets/branding/videomoney_splash.png'
          : 'assets/branding/videomoney_logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Text(
          'VideoMoney',
          style: Theme.of(context).textTheme.headlineMedium,
        );
      },
    );
  }
}
