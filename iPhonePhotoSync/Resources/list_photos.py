#!/usr/bin/env python3
"""list_photos.py
Lists all photo/video files on the connected iPhone.
Outputs one JSON line per file:
  {"path": "/DCIM/100APPLE/IMG_1234.HEIC", "size": 4200000}
Finishes with: DONE <total>
"""
import sys
import os
import asyncio
import warnings
import json

warnings.filterwarnings('ignore')

try:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.afc import AfcService
except ImportError:
    print("ERROR pymobiledevice3 not installed")
    sys.exit(1)


async def main():
    lockdown = await create_using_usbmux()
    afc = AfcService(lockdown)
    total = 0
    async for dir_path, _, files in afc.walk('/DCIM'):
        for filename in files:
            remote = f'{dir_path}/{filename}'
            try:
                st = await afc.stat(remote)
                size = int(st.get('st_size', 0))
            except Exception:
                size = 0
            print(json.dumps({'path': remote, 'size': size}), flush=True)
            total += 1
    afc.close()
    print(f'DONE {total}', flush=True)


if __name__ == '__main__':
    asyncio.run(main())
