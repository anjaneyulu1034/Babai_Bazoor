import 'package:babai_bazor_app/core/constants/app_assets.dart';
import 'package:flutter/material.dart';

/// Babai Bazaar logo used on splash, login, and other branded screens.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.width = 112,
    this.height = 112,
    this.borderRadius = 26,
    this.fit = BoxFit.contain,
  });

  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        AppAssets.logo,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
