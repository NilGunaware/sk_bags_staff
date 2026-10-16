# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path
from PyInstaller.utils.win32.versioninfo import VSVersionInfo, FixedFileInfo, StringFileInfo, StringTable, StringStruct, VarFileInfo, VarStruct

project_root = Path.cwd()
version_namespace = {}
exec((project_root / "app" / "version.py").read_text(encoding="utf-8"), version_namespace)
app_version = version_namespace["APP_VERSION"]
version_tuple = tuple(int(part) for part in app_version.split('.')) + (0,)
windows_version = VSVersionInfo(
    ffi=FixedFileInfo(filevers=version_tuple, prodvers=version_tuple,
        mask=0x3f, flags=0, OS=0x40004, fileType=0x1, subtype=0, date=(0, 0)),
    kids=[StringFileInfo([StringTable('040904B0', [
        StringStruct('CompanyName', 'SK Bags'),
        StringStruct('FileDescription', 'SK Bags API Desktop'),
        StringStruct('FileVersion', app_version),
        StringStruct('ProductVersion', app_version),
        StringStruct('ProductName', 'SK Bags Desktop'),
        StringStruct('OriginalFilename', f'SKBagsDesktop-{app_version}.exe'),
    ])]), VarFileInfo([VarStruct('Translation', [1033, 1200])])],
)

datas = [
    (str(project_root / ".env.example"), "."),
    (str(project_root / "app" / "static"), "app/static"),
]

hiddenimports = [
    "uvicorn.logging",
    "uvicorn.loops.auto",
    "uvicorn.protocols.http.auto",
    "uvicorn.protocols.websockets.auto",
    "uvicorn.protocols.websockets.websockets_impl",
    "websockets.legacy.server",
    "uvicorn.lifespan.on",
]


a = Analysis(
    ["desktop_app.py"],
    pathex=[str(project_root)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    exclude_binaries=False,
    name=f"SKBagsDesktop-{app_version}",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    version=windows_version,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
