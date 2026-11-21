#!/usr/bin/env python3
"""list_photos.py
Lists photos/videos on a connected iPhone, streaming one JSON line per file.
Each line: {"path": ..., "size": ..., "thumb": "<base64 jpeg>"}
Finishes with: DONE <total>
"""
import sys, os, asyncio, warnings, json, base64, tempfile, subprocess
warnings.filterwarnings('ignore')

try:
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.afc import AfcService
except ImportError:
    print("ERROR pymobiledevice3 not installed")
    sys.exit(1)


def make_thumb(data: bytes, ext: str) -> str:
    """Return base64-encoded 120x120 JPEG thumbnail, or empty string on failure."""
    try:
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as f:
            f.write(data)
            src = f.name
        dst = src + '_thumb.jpg'
        result = subprocess.run(
            ['sips', '-z', '120', '120', src, '--out', dst],
            capture_output=True, timeout=10
        )
        if result.returncode == 0 and os.path.exists(dst):
            with open(dst, 'rb') as f:
                b64 = base64.b64encode(f.read()).decode()
            return b64
    except Exception:
        pass
    finally:
        try: os.unlink(src)
        except: pass
        try: os.unlink(dst)
        except: pass
    return ''


async def main():
    lockdown = await create_using_usbmux()
    afc = AfcService(lockdown)
    total = 0

    async for dir_path, _, files in afc.walk('/DCIM'):
        for filename in files:
            remote = f'{dir_path}/{filename}'
            ext = os.path.splitext(filename)[1].lower()

            # Get size
            size = 0
            try:
                st = await afc.stat(remote)
                size = int(st.get('st_size', 0))
            except Exception:
                pass

            # Pull file for thumbnail (skip very large videos > 200MB)
            thumb = ''
            if size < 200 * 1024 * 1024:
                try:
                    data = await afc.get_file_contents(remote)
                    thumb = make_thumb(data, ext)
                except Exception:
                    pass

            print(json.dumps({'path': remote, 'size': size, 'thumb': thumb}), flush=True)
            total += 1

    afc.close()
    print(f'DONE {total}', flush=True)


if __name__ == '__main__':
    asyncio.run(main())
