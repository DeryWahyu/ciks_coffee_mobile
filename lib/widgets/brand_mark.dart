import 'package:flutter/material.dart';

/// The striped C from the CIKS logo, shared by all compact brand surfaces.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.color});

  static const asset = 'assets/branding/cikscoffee-mark.png';
  static const espresso = Color(0xFF4A3022);
  static const cream = Color(0xFFFAF7F3);

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Logo Ciks Coffee',
    );
  }
}

/// Full CIKS lettering for brand areas with enough horizontal space.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.width = 144, this.color});

  static const asset = 'assets/branding/cikscoffee-wordmark.png';
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: width / 2.2,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      filterQuality: FilterQuality.high,
      semanticLabel: 'CIKS',
    );
  }
}
