import 'dart:io';

import 'package:image/image.dart' as img;

/// Platform exports from the generated CIKS C master; never redraw the artwork.
void main(List<String> arguments) {
  img.Image readArtwork(String path) {
    final source = img.decodePng(File(path).readAsBytesSync())!;
    var left = source.width, top = source.height, right = -1, bottom = -1;
    for (final pixel in source) {
      if (pixel.a <= 8) continue;
      if (pixel.x < left) left = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y > bottom) bottom = pixel.y;
    }
    if (right < left || bottom < top) {
      throw StateError('Empty brand artwork: $path');
    }
    return img.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    );
  }

  final mark = readArtwork('assets/branding/source/cikscoffee-c-master.png');
  final wordmark = readArtwork(
    'assets/branding/source/cikscoffee-wordmark-master.png',
  );

  img.Image fitArtwork(
    img.Image artwork,
    int width,
    int height,
    int padding, {
    bool opaque = false,
  }) {
    final result = img.Image(width: width, height: height, numChannels: 4);
    img.fill(result, color: img.ColorRgba8(250, 247, 243, opaque ? 255 : 0));
    final scaleX = (width - padding * 2) / artwork.width;
    final scaleY = (height - padding * 2) / artwork.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final resized = img.copyResize(
      artwork,
      width: (artwork.width * scale).round(),
      height: (artwork.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
    img.compositeImage(
      result,
      resized,
      dstX: (width - resized.width) ~/ 2,
      dstY: (height - resized.height) ~/ 2,
    );
    return result;
  }

  img.Image canvas(int size, int markSize, {bool opaque = false}) {
    return fitArtwork(mark, size, size, (size - markSize) ~/ 2, opaque: opaque);
  }

  void save(String path, img.Image image) {
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image, level: 9));
  }

  final runtimeMark = canvas(512, 492);
  final runtimeWordmark = fitArtwork(wordmark, 1024, 464, 16);
  save('assets/branding/cikscoffee-mark.png', runtimeMark);
  save('assets/branding/cikscoffee-wordmark.png', runtimeWordmark);

  // Optional export for the sibling Laravel checkout in this workspace.
  if (arguments.contains('--web')) {
    const web = '../ciks_coffee_web/public/images/branding';
    if (!Directory('../ciks_coffee_web/public').existsSync()) {
      throw StateError('The sibling web checkout was not found.');
    }
    save('$web/cikscoffee-c-mark.png', runtimeMark);
    save('$web/cikscoffee-wordmark.png', runtimeWordmark);
    save('$web/cikscoffee-favicon-32.png', canvas(32, 30));
    save('$web/cikscoffee-favicon-64.png', canvas(64, 60));
    // Keep the browser fallback and the previous favicon URL on the same C mark.
    File('../ciks_coffee_web/public/favicon.ico').writeAsBytesSync(
      img.IcoEncoder().encodeImages([
        for (final size in [16, 32, 48, 64]) canvas(size, size - 2),
      ]),
    );
    save(
      '../ciks_coffee_web/public/images/cikscoffee-favicon-v2.png',
      canvas(64, 60),
    );
    save(
      '$web/cikscoffee-apple-touch-icon.png',
      canvas(180, 140, opaque: true),
    );
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
