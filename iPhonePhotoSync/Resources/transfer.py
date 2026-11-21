#!/usr/bin/env python3
"""transfer.py <destination_dir> [remote_path ...]

If remote_paths are provided, copies only those files.
Otherwise copies all files under /DCIM.

Outputs:
  COPYING <remote_path>
  PROGRESS <copied> <total>
  ERROR <message>
  DONE <total_copied>
"""
import sys
import os
import asyncio
import warnings

warnings.filterwarnings('ignore')

try:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.afc import AfcService
except ImportError:
    print("ERROR pymobiledevice3 is not installed. Run: pip3 install pymobiledevice3")
    sys.exit(1)


async def main(dest: str, selected: list):
    os.makedirs(dest, exist_ok=True)

    lockdown = await create_using_usbmux()
    afc = AfcService(lockdown)

    if selected:
        # Copy only selected files
        total = len(selected)
        copied = 0
        for remote in selected:
            filename = os.path.basename(remote)
            local = os.path.join(dest, filename)
            if os.path.exists(local):
                subfolder = os.path.dirname(remote).strip('/').replace('/', '_')
                local = os.path.join(dest, f'{subfolder}_{filename}')
            print(f'COPYING {remote}', flush=True)
            try:
                await afc.pull(remote, local)
                copied += 1
                print(f'PROGRESS {copied} {total}', flush=True)
            except Exception as e:
                print(f'ERROR {remote}: {e}', flush=True)
    else:
        # Copy everything under /DCIM
        total = 0
        async for _, _, files in afc.walk('/DCIM'):
            total += len(files)

        copied = 0
        async for dir_path, _, files in afc.walk('/DCIM'):
            for filename in files:
                remote = f'{dir_path}/{filename}'
                local = os.path.join(dest, filename)
                if os.path.exists(local):
                    subfolder = dir_path.strip('/').replace('/', '_')
                    local = os.path.join(dest, f'{subfolder}_{filename}')
                print(f'COPYING {remote}', flush=True)
                try:
                    await afc.pull(remote, local)
                    copied += 1
                    print(f'PROGRESS {copied} {total}', flush=True)
                except Exception as e:
                    print(f'ERROR {remote}: {e}', flush=True)

    afc.close()
    print(f'DONE {copied}', flush=True)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("ERROR Usage: transfer.py <destination_dir> [remote_path ...]")
        sys.exit(1)
    dest = sys.argv[1]
    selected = sys.argv[2:]
    asyncio.run(main(dest, selected))
