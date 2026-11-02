"""Check the actual delivery chain. This does not execute Windows CMD."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import re
root = Path(__file__).resolve().parents[1]
package = root / 'downloads/CE-Modern-Windows.zip'
bootstrap = (root / 'downloads/Baixar-CE-Modern.cmd').read_bytes()
checksum = hashlib.sha256(package.read_bytes()).hexdigest()
expected = re.search(rb'CE_MODERN_SHA256=([0-9a-f]{64})', bootstrap)[1].decode()
assert checksum == expected, 'Bootstrap must verify the actual packaged ZIP'
assert checksum == (root / 'downloads/SHA256SUMS.txt').read_text().split()[0]
with ZipFile(package) as archive:
    assert archive.testzip() is None
    install = archive.read('CE-Modern/Instalar.cmd')
    assert install == (root / 'Instalar.cmd').read_bytes(), 'ZIP must contain the current installer'
    names = set(archive.namelist())
    for entry in ['ce_modern.lua', 'ce_modern/core.lua', 'ce_modern/engine.lua', 'ce_modern/voice.ps1']:
        assert 'CE-Modern/autorun/' + entry in names
for content in (bootstrap, install):
    assert b'\r\n' in content and b'\n' not in content.replace(b'\r\n', b''), 'CMD must use consistent CRLF'
    assert not content.startswith(b'\xef\xbb\xbf'), 'CMD entry point must not have a UTF-8 BOM'
    # Every goto must point to a real label so error paths remain actionable.
    labels = {line[1:].lower() for line in content.decode().splitlines() if line.startswith(':')}
    targets = set(re.findall(r'\bgoto\s+:([a-z]+)', content.decode(), re.I))
    assert targets <= labels, targets - labels
assert b'shift /1' in install, 'Worker switch must preserve %0 and the installer source directory'
print('PASS: packaged files, SHA-256 delivery chain, CRLF, error labels and installer source path')
