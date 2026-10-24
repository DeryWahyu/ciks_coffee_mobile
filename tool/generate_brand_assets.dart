import 'dart:io';

import 'package:image/image.dart' as img;

/// Platform exports of the approved mark; never redraw or regenerate the logo.
void main() {
  final mark = img.decodePng(
    File('assets/branding/cikscoffee-mark.png').readAsBytesSync(),
  )!;

  img.Image canvas(int size, int markSize, {bool opaque = false}) {
    final result = img.Image(width: size, height: size, numChannels: 4);
    img.fill(result, color: img.ColorRgba8(250, 247, 243, opaque ? 255 : 0));
    final resized = img.copyResize(
      mark,
      width: markSize,
      height: markSize,
      interpolation: img.Interpolation.average,
    );
    img.compositeImage(
      result,
      resized,
      dstX: (size - markSize) ~/ 2,
      dstY: (size - markSize) ~/ 2,
    );
    return result;
  }

  void save(String path, img.Image image) {
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image));
  }

  save(
    'assets/branding/cikscoffee-app-icon.png',
    canvas(1024, 760, opaque: true),
  );
  // The full silhouette stays within the safe center of adaptive launcher masks.
  save('assets/branding/cikscoffee-adaptive-foreground.png', canvas(1024, 620));

  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };
  for (final entry in densities.entries) {
    final folder = 'android/app/src/main/res/drawable-${entry.key}';
    save(
      '$folder/brand_splash.png',
      canvas((160 * entry.value).round(), (128 * entry.value).round()),
    );
    // Android 12: 288dp canvas, artwork within a 192dp diameter safe circle.
    save(
      '$folder/brand_splash_android12.png',
      canvas((288 * entry.value).round(), (168 * entry.value).round()),
    );
    final notification = canvas(
      (24 * entry.value).round(),
      (22 * entry.value).round(),
    );
    for (final pixel in notification) {
      pixel.r = 255;
      pixel.g = 255;
      pixel.b = 255;
    }
    save('$folder/ic_notification.png', notification);
    final monochrome = canvas(
      (108 * entry.value).round(),
      (65 * entry.value).round(),
    );
    for (final pixel in monochrome) {
      pixel.r = 255;
      pixel.g = 255;
      pixel.b = 255;
    }
    save('$folder/ic_launcher_monochrome.png', monochrome);
  }
  for (var scale = 1; scale <= 3; scale++) {
    final suffix = scale == 1 ? '' : '@${scale}x';
    save(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
      canvas(160 * scale, 128 * scale),
    );
  }
  stdout.writeln('Brand exports ready. Run: dart run flutter_launcher_icons');
}
