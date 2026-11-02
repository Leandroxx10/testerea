"""Pure scan routines with explicit cancellation and bounded results."""
import math
import struct

TYPES = {'Inteiro · 4 bytes': 'i', 'Inteiro · 1 byte': 'b', 'Inteiro · 2 bytes': 'h',
         'Inteiro · 8 bytes': 'q', 'Decimal · simples': 'f', 'Decimal · duplo': 'd'}
MODES = ['Igual ao valor', 'Valor mudou', 'Valor não mudou', 'Valor aumentou', 'Valor diminuiu']
LIMIT = 100_000

def encode(value, kind):
    if kind not in TYPES.values():
        raise ValueError('Tipo de dado não suportado.')
    value = float(str(value).replace(',', '.')) if kind in ('f', 'd') else int(str(value), 10)
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError('Informe um número finito.')
    try:
        return struct.pack('<' + kind, value)
    except (struct.error, OverflowError) as error:
        raise ValueError('O valor não cabe no tipo de dado escolhido.') from error

def decode(data, kind):
    return struct.unpack('<' + kind, data)[0]

def hits(data, base, needle):
    pos = data.find(needle)
    while pos != -1:
        if (base + pos) % len(needle) == 0:
            yield base + pos
        pos = data.find(needle, pos + 1)

def scan(memory, pid, kind, value, previous=None, mode=0, cancelled=lambda: False, progress=lambda n: None):
    size = struct.calcsize('<' + kind)
    if mode not in range(len(MODES)):
        raise ValueError('Comparação desconhecida.')
    if previous is None and mode:
        raise ValueError('Faça uma primeira busca por um valor conhecido antes de refinar.')
    needle = encode(value, kind) if mode == 0 else None
    found = {}; examined = 0
    with memory.handle(pid) as handle:
        if previous is not None:
            for address, old in previous.items():
                if cancelled():
                    raise InterruptedError('Busca cancelada. Os resultados anteriores foram mantidos.')
                data = memory.read_handle(handle, address, size)
                if len(data) == size:
                    current = decode(data, kind)
                    matches = [data == needle, current != old, current == old, current > old, current < old]
                    if matches[mode]:
                        found[address] = current
                examined += 1
                if examined % 2048 == 0:
                    progress(examined)
            return found, False
        for base, length in memory.regions(handle):
            for offset in range(0, length, 1024 * 1024):
                if cancelled():
                    raise InterruptedError('Busca cancelada. Os resultados anteriores foram mantidos.')
                count = min(1024 * 1024, length - offset)
                # Include overlap so matches at chunk boundaries are not lost.
                data = memory.read_handle(handle, base + offset, min(count + size - 1, length - offset))
                for address in hits(data, base + offset, needle):
                    if address >= base + offset + count:
                        break
                    found[address] = decode(needle, kind)
                    if len(found) >= LIMIT:
                        return found, True
                examined += len(data)
                progress(examined)
    return found, False
