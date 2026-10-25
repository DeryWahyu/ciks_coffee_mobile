"""Guard against advertising an ABI whose Flutter engine cannot run."""
from pathlib import Path
import tempfile
import unittest
import zipfile

from build_android_release import validate_native_libraries


class NativeLibraryCompatibilityTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='cikscoffee-apk-test-')
        self.addCleanup(directory.cleanup)
        self.apk = Path(directory.name) / 'fixture.apk'

    def package(self, libraries):
        with zipfile.ZipFile(self.apk, 'w') as apk:
            for library in libraries:
                apk.writestr(library, b'native-library-fixture')

    def test_complete_single_abi_package_is_accepted(self):
        self.package([
            'lib/arm64-v8a/libapp.so',
            'lib/arm64-v8a/libflutter.so',
            'lib/arm64-v8a/libdartjni.so',
        ])
        self.assertEqual(validate_native_libraries(self.apk, {'arm64-v8a'}),
                         ['arm64-v8a'])

    def test_plugin_library_cannot_advertise_another_abi(self):
        self.package([
            'lib/armeabi-v7a/libapp.so',
            'lib/armeabi-v7a/libflutter.so',
            'lib/arm64-v8a/libdartjni.so',
        ])
        with self.assertRaises(ValueError):
            validate_native_libraries(self.apk, {'armeabi-v7a'})

    def test_application_requires_a_matching_flutter_engine(self):
        self.package(['lib/arm64-v8a/libapp.so'])
        with self.assertRaises(ValueError):
            validate_native_libraries(self.apk, {'arm64-v8a'})


if __name__ == '__main__':
    unittest.main()
