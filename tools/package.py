"""Build the distributable from authored files only; never include CE binaries."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
root = Path(__file__).resolve().parents[1]
output = root / 'downloads/CE-Modern-Windows.zip'
output.parent.mkdir(exist_ok=True)
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for name in ['README.md', 'Instalar.cmd', 'Instalar.ps1', 'autorun', 'tests']:
        source = root / name
        files = [source] if source.is_file() else sorted(source.rglob('*'))
        for path in files:
            if path.is_file() and '__pycache__' not in path.parts:
                archive.write(path, Path('CE-Modern') / path.relative_to(root))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    required = ['autorun/ce_modern.lua', 'autorun/ce_modern/core.lua', 'autorun/ce_modern/engine.lua', 'autorun/ce_modern/voice.ps1', 'Instalar.cmd']
    for name in required:
        assert 'CE-Modern/' + name in archive.namelist(), name
    assert not any(name.lower().endswith(('.exe', '.dll')) for name in archive.namelist())
digest = hashlib.sha256(output.read_bytes()).hexdigest()
(root / 'downloads/SHA256SUMS.txt').write_text(digest + '  CE-Modern-Windows.zip\n')
print(str(output), output.stat().st_size, 'bytes', digest)
