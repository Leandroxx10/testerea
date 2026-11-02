from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib
root=Path(__file__).resolve().parents[1]
output=root/'downloads/MemoriaStudio-Fonte.zip'
output.parent.mkdir(parents=True,exist_ok=True)
with ZipFile(output,'w',ZIP_DEFLATED) as archive:
    for path in sorted((root/'standalone').rglob('*')):
        if not path.is_file() or any(p in ('__pycache__','.venv','dist','build') for p in path.parts):continue
        archive.write(path,Path('MemoriaStudio')/path.relative_to(root/'standalone'))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert not any('/autorun/' in n or n.endswith(('.dll','.exe')) for n in archive.namelist())
(root/'downloads/SHA256SUMS.txt').write_text(hashlib.sha256(output.read_bytes()).hexdigest()+'  '+output.name+'\n')
print(output,output.stat().st_size)
