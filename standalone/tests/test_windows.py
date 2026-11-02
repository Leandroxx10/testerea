"""Native integration test; runs only on Windows using memory owned by this test."""
import ctypes
import os
import unittest
from memoria_studio.native import WindowsMemory

@unittest.skipUnless(os.name=='nt','Windows API required')
class WindowsTests(unittest.TestCase):
    def test_current_process_read_write_and_listing(self):
        memory=WindowsMemory();value=ctypes.c_int32(123456);address=ctypes.addressof(value)
        self.assertEqual(memory.read(os.getpid(),address,4),bytes(value))
        memory.write(os.getpid(),address,bytes(ctypes.c_int32(654321)));self.assertEqual(value.value,654321)
        self.assertIn(os.getpid(),[p.pid for p in memory.processes()])
        with memory.handle(os.getpid()) as handle:self.assertTrue(any(base<=address<base+size for base,size in memory.regions(handle)))
if __name__=='__main__':unittest.main()
