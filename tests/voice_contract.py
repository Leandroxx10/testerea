"""Static cross-language contract checks; not a Windows speech runtime test."""
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
voice = (root / 'autorun/ce_modern/voice.ps1').read_bytes()
assert voice.startswith(b'\xef\xbb\xbf'), 'Windows PowerShell 5.1 requires BOM for Portuguese strings'
source = voice.decode('utf-8-sig')
tokens = set(re.findall(r"'[^']+'\s*=\s*'([a-z]+)'", source))
core = (root / 'autorun/ce_modern/core.lua').read_text()
whitelist = set(re.findall(r"\b([a-z]+)\s*=\s*'[a-z]+'", core))
assert tokens == whitelist, (tokens, whitelist)
assert len(tokens) == 9
for p in root.rglob('*.lua'):
    assert b'\0' not in p.read_bytes(), p
assert 'Invoke-Expression' not in source
assert 'System.Speech.Recognition' in source
assert '0.80' in source
print('PASS: 9 voice tokens match Lua whitelist; UTF-8 BOM and local speech contract verified')
