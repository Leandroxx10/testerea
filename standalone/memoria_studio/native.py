"""Independent Windows process-memory backend. Does not load Cheat Engine."""
import ctypes as c
import os
from dataclasses import dataclass
from contextlib import contextmanager

@dataclass(frozen=True)
class Process:
    pid: int
    name: str

class WindowsMemory:
    def __init__(self):
        if os.name != 'nt':
            raise OSError('A conexão a processos está disponível somente no Windows de 64 bits.')
        if c.sizeof(c.c_void_p) != 8:
            raise OSError('Use Python/Windows de 64 bits.')
        self.k = c.WinDLL('kernel32', use_last_error=True)
        ptr, u32, size = c.c_void_p, c.c_uint32, c.c_size_t
        for name, args, result in [
            ('OpenProcess', [u32, c.c_int, u32], ptr),
            ('CloseHandle', [ptr], c.c_int),
            ('CreateToolhelp32Snapshot', [u32, u32], ptr),
            ('Process32FirstW', [ptr, ptr], c.c_int),
            ('Process32NextW', [ptr, ptr], c.c_int),
            ('ReadProcessMemory', [ptr, ptr, ptr, size, c.POINTER(size)], c.c_int),
            ('WriteProcessMemory', [ptr, ptr, ptr, size, c.POINTER(size)], c.c_int),
            ('VirtualQueryEx', [ptr, ptr, ptr, size], size),
        ]:
            fn = getattr(self.k, name); fn.argtypes = args; fn.restype = result

    @contextmanager
    def handle(self, pid, write=False):
        access = 0x28 if write else 0x410
        handle = self.k.OpenProcess(access, False, pid)
        if not handle:
            raise OSError(c.get_last_error(), 'Não foi possível abrir o processo. Confira se ele está aberto e suas permissões.')
        try:
            yield handle
        finally:
            self.k.CloseHandle(handle)

    def processes(self):
        class Entry(c.Structure):
            _fields_ = [('size', c.c_uint32), ('usage', c.c_uint32), ('pid', c.c_uint32),
                        ('heap', c.c_size_t), ('module', c.c_uint32), ('threads', c.c_uint32),
                        ('parent', c.c_uint32), ('priority', c.c_int32), ('flags', c.c_uint32),
                        ('name', c.c_wchar * 260)]
        snapshot = self.k.CreateToolhelp32Snapshot(2, 0)
        if snapshot == c.c_void_p(-1).value:
            raise OSError(c.get_last_error(), 'Falha ao listar processos.')
        try:
            entry = Entry(); entry.size = c.sizeof(entry)
            valid = self.k.Process32FirstW(snapshot, c.byref(entry)); rows = []
            while valid:
                if entry.pid:
                    rows.append(Process(entry.pid, entry.name))
                valid = self.k.Process32NextW(snapshot, c.byref(entry))
            return sorted(rows, key=lambda p: (p.name.lower(), p.pid))
        finally:
            self.k.CloseHandle(snapshot)

    def regions(self, handle):
        class Region(c.Structure):
            _fields_ = [('base', c.c_void_p), ('allocation', c.c_void_p), ('allocation_protect', c.c_uint32),
                        ('partition', c.c_uint16), ('size', c.c_size_t), ('state', c.c_uint32),
                        ('protect', c.c_uint32), ('type', c.c_uint32)]
        address = 0
        while address < 0x7fffffffffff:
            r = Region()
            if not self.k.VirtualQueryEx(handle, address, c.byref(r), c.sizeof(r)):
                break
            base = r.base or 0
            if r.state == 0x1000 and not r.protect & 0x100 and r.protect & 0xff in (2, 4, 8, 0x20, 0x40, 0x80):
                yield base, r.size
            following = base + r.size
            if following <= address:
                break
            address = following

    def read_handle(self, handle, address, size):
        buffer = c.create_string_buffer(size); read = c.c_size_t()
        self.k.ReadProcessMemory(handle, address, buffer, size, c.byref(read))
        return buffer.raw[:read.value]

    def read(self, pid, address, size):
        if not 1 <= size <= 1024 * 1024:
            raise ValueError('Leia entre 1 byte e 1 MB por operação.')
        with self.handle(pid) as handle:
            data = self.read_handle(handle, address, size)
            if not data:
                raise OSError('O endereço não pôde ser lido.')
            return data

    def write(self, pid, address, data):
        with self.handle(pid, write=True) as handle:
            written = c.c_size_t(); buffer = c.create_string_buffer(data)
            ok = self.k.WriteProcessMemory(handle, address, buffer, len(data), c.byref(written))
            if not ok or written.value != len(data):
                raise OSError(c.get_last_error(), 'O valor não pôde ser escrito. Confira o endereço e as permissões.')
