#!/usr/bin/env python3
"""Check the compiled API endpoint in every Flutter ABI before publishing."""
import sys
import zipfile

endpoint = b'https://cikscoffee.biz.id/api'
with zipfile.ZipFile(sys.argv[1]) as apk:
    libraries = [name for name in apk.namelist() if name.endswith('/libapp.so')]
    if not libraries:
        raise ValueError('Flutter application libraries missing')
    for name in libraries:
        content = apk.read(name)
        if endpoint not in content:
            raise ValueError(f'Production API endpoint missing in {name}')
        if b'192.168.18.189' in content:
            raise ValueError(f'Old local server endpoint present in {name}')
        print(f'Production API verified: {name}')
