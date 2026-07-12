import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WatermarkHeroCard extends StatelessWidget {
  const WatermarkHeroCard({
    super.key,
    required this.child,
    required this.imageAsset,
    this.height = 220,
    this.imageAlignment = Alignment.centerRight,
    this.imageOpacity = 0.22,
    this.imageScale = 1.18,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final String imageAsset;
  final double height;
  final Alignment imageAlignment;
  final double imageOpacity;
  final double imageScale;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF11261C),
            Color(0xFF08120E),
            Color(0xFF04100A),
          ],
        ),
        border: Border.all(color: AppTheme.outline.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: imageAlignment,
                child: Transform.scale(
                  scale: imageScale,
                  child: Opacity(
                    opacity: imageOpacity,
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xD80A140F),
                      Color(0xB809110D),
                      Color(0x5C07100B),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
