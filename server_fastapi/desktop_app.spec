# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

project_root = Path.cwd()
version_namespace = {}
exec((project_root / "app" / "version.py").read_text(encoding="utf-8"), version_namespace)
app_version = version_namespace["APP_VERSION"]

datas = [
    (str(project_root / ".env.example"), "."),
    (str(project_root / "app" / "static"), "app/static"),
]

hiddenimports = [
    "uvicorn.logging",
    "uvicorn.loops.auto",
    "uvicorn.protocols.http.auto",
    "uvicorn.protocols.websockets.auto",
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
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
