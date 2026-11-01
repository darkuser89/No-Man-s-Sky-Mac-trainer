#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${MT_TRAINER_BUILD_DIR:-$HOME/Documents/Codex/Builds/NoMansSkyTrainer}"
python3 - "$ROOT" "$BUILD" <<'PY'
from pathlib import Path
import hashlib, json, plistlib, subprocess, sys, tempfile

source, build = (Path(value).expanduser().resolve() for value in sys.argv[1:])
if source == build or source in build.parents:
    raise SystemExit('Release packages must remain outside source.')
config = json.loads((source / 'Resources/TrainerConfig.json').read_text())['app']
app = build / (config['name'] + '.app')
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
for field, key in [('CFBundleIdentifier', 'bundleIdentifier'), ('CFBundleShortVersionString', 'version'), ('CFBundleVersion', 'build')]:
    if info[field] != config[key]:
        raise SystemExit('Build does not match current config: ' + field)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
release = build / 'Release'
release.mkdir(exist_ok=True)
filename = f"NoMansSkyTrainer-{config['version']}-macOS-arm64.zip"
archive = release / filename
with tempfile.TemporaryDirectory(prefix='release-check-', dir=build) as temporary:
    staged = Path(temporary) / filename
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(staged)], check=True)
    extracted = Path(temporary) / 'extracted'
    subprocess.run(['ditto', '-x', '-k', str(staged), str(extracted)], check=True)
    restored = extracted / app.name
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(restored)], check=True)
    for relative in ['Contents/MacOS/MacTrainer', 'Contents/Resources/TrainerOverlay.dylib', 'Contents/Resources/AppIcon.icns']:
        if (app / relative).read_bytes() != (restored / relative).read_bytes():
            raise SystemExit('Archive round-trip mismatch: ' + relative)
    staged.replace(archive)
# Keep only the current archive produced by this script.
for previous in release.glob('NoMansSkyTrainer-*-macOS-arm64.zip'):
    if previous != archive:
        previous.unlink()
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(release / 'SHA256SUMS').write_text(f'{digest}  {filename}\n')
(release / 'RELEASE_NOTES.md').write_text(f'''No Man’s Sky Trainer {config['version']} (Build {config['build']})

- macOS 14 oder neuer, Apple Silicon, Steam-Version mit arm64-UUID `2E807BC6-A953-3F93-B723-42A2FB9E39CB`.
- 27 Referenzfunktionen plus 3 Extras; Atlas-Icon und angepasster Launcher.
- Enthaltene synthetische Adapter-, Overlay- und Regressionstests müssen vor Veröffentlichung bestehen. CI führt keine Spieltests aus.
- Im Spiel geprüft: Währungsgaben und -bestände, Stapelauffüllen, Werkzeugenergie/-hitze, materialfreies Herstellen und Gefahrenschutz. Weitere Funktionen sind nur teilweise oder noch nicht auf ihre Spielwirkung geprüft.
- Ad-hoc signiert, nicht Apple-notarisiert. Auffüllen und Währungsgaben können vom Spiel gespeichert werden.

ZIP entpacken und die App öffnen. Steam geöffnet lassen; das Spiel über den Trainer starten. ⌘ + ^ öffnet das Overlay samt Maus, Esc schließt es; ⇧F9 schaltet alles aus.

Quellcode, genaue Kompatibilität und Tasten: siehe README im Repository. SHA256SUMS enthält die Prüfsumme des Downloads.
''')
print(archive)
print(digest)
PY
