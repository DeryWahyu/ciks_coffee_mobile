#!/usr/bin/env python3
"""Build smaller standalone APKs and a universal fallback for manual installs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'build' / 'android-release'
SYMBOLS = ROOT / 'build' / 'android-symbols'
FLUTTER_APK = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
TARGETS = (
    ('universal', 'android-arm,android-arm64,android-x64',
     {'armeabi-v7a', 'arm64-v8a', 'x86_64'}, 'app-release.apk'),
    ('arm64-v8a', 'android-arm64', {'arm64-v8a'},
     'ciks-coffee-mobile-arm64-v8a.apk'),
    ('armeabi-v7a', 'android-arm', {'armeabi-v7a'},
     'ciks-coffee-mobile-armeabi-v7a.apk'),
    ('x86_64', 'android-x64', {'x86_64'},
     'ciks-coffee-mobile-x86_64.apk'),
)


def validate_native_libraries(path, expected_abis):
    with zipfile.ZipFile(path) as apk:
        libraries = [name for name in apk.namelist()
                     if name.startswith('lib/') and name.endswith('.so')]
    for suffix in ('.so', '/libapp.so', '/libflutter.so'):
        actual_abis = {name.split('/')[1] for name in libraries
                       if name.endswith(suffix)}
        if actual_abis != expected_abis:
            raise ValueError(f'{path.name}: unexpected ABIs for {suffix}: {actual_abis}')
    return sorted(expected_abis)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-number', type=int, required=True)
    args = parser.parse_args()
    if args.build_number < 1:
        parser.error('--build-number must be positive')
    flutter = shutil.which('flutter')
    if flutter is None:
        parser.error('flutter must be available on PATH')

    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'manifest.json').unlink(missing_ok=True)
    packages = []
    for name, platform, expected_abis, filename in TARGETS:
        symbols = SYMBOLS / name
        print(f'Building {name}...', flush=True)
        # Separate target-platform builds keep one versionCode across APKs.
        # Flutter's --split-per-abi adds offsets that can block later updates
        # when switching between a device APK and the universal fallback.
        subprocess.run([
            flutter, 'build', 'apk', '--no-pub', '--release',
            '--target=lib/main.dart', f'--target-platform={platform}',
            f'--build-number={args.build_number}',
            f'--split-debug-info={symbols}',
            '--android-project-arg=disable-abi-filtering=true',
        ], cwd=ROOT, check=True)

        actual_abis = validate_native_libraries(FLUTTER_APK, expected_abis)
        if not list(symbols.glob('*.symbols')):
            raise ValueError(f'{name}: debug symbols missing')
        subprocess.run([
            sys.executable, str(ROOT / 'tool/verify_production_apk.py'),
            str(FLUTTER_APK),
        ], cwd=ROOT, check=True)

        destination = OUTPUT / filename
        shutil.copy2(FLUTTER_APK, destination)
        size = destination.stat().st_size
        if packages and size >= packages[0]['bytes']:
            raise ValueError(f'{name}: device APK must be smaller than universal')
        packages.append({
            'file': filename,
            'abis': sorted(actual_abis),
            'bytes': size,
            'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
            'symbols': str(symbols.relative_to(ROOT)).replace('\\', '/'),
        })
        print(f'{filename}: {size / 1_000_000:.2f} MB', flush=True)

    # Preserve the existing local/publication path as the universal fallback.
    shutil.copy2(OUTPUT / 'app-release.apk', FLUTTER_APK)
    (OUTPUT / 'manifest.json').write_text(json.dumps({
        'build_number': args.build_number, 'packages': packages,
    }, indent=2) + '\n', encoding='utf-8')
    print(f'Release packages: {OUTPUT}', flush=True)


if __name__ == '__main__':
    main()
