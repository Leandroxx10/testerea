import struct
import unittest
from contextlib import contextmanager
from memoria_studio.scanner import encode,decode,hits,scan

class Memory:
    def __init__(self,data):self.data=data
    @contextmanager
    def handle(self,pid):yield 1
    def regions(self,handle):yield 0x1000,len(self.data)
    def read_handle(self,handle,address,size):return self.data[address-0x1000:address-0x1000+size]

class ScannerTests(unittest.TestCase):
    def test_encode_decode(self):
        self.assertEqual(decode(encode('1,25','f'),'f'),1.25)
        for value,kind in [('999','b'),('nan','f'),('inf','d'),('text','i')]:
            with self.assertRaises(ValueError):encode(value,kind)
    def test_alignment(self):
        self.assertEqual(list(hits(b'\x01'*12,0,b'\x01'*4)),[0,4,8])
    def test_first_and_refine(self):
        memory=Memory(struct.pack('<iiii',100,10,100,30));found,limit=scan(memory,1,'i','100')
        self.assertFalse(limit);self.assertEqual(found,{0x1000:100,0x1008:100})
        memory.data=struct.pack('<iiii',200,10,100,30)
        changed,_=scan(memory,1,'i','',found,1);self.assertEqual(changed,{0x1000:200})
        equal,_=scan(memory,1,'i','100',found,0);self.assertEqual(equal,{0x1008:100})
        unchanged,_=scan(memory,1,'i','',found,2);self.assertEqual(unchanged,{0x1008:100})
        increase,_=scan(memory,1,'i','',found,3);self.assertEqual(increase,{0x1000:200})
    def test_cancel_does_not_mutate_previous(self):
        previous={0x1000:100}
        with self.assertRaises(InterruptedError):scan(Memory(b'\0'*16),1,'i','100',previous,0,cancelled=lambda:True)
        self.assertEqual(previous,{0x1000:100})
    def test_boundary(self):
        size=1024*1024;data=bytearray(size+16);data[size-4:size]=encode(123,'i');data[size:size+4]=encode(123,'i')
        found,_=scan(Memory(data),1,'i','123');self.assertEqual(list(found),[0x1000+size-4,0x1000+size])
    def test_unknown_initial_comparison(self):
        with self.assertRaises(ValueError):scan(Memory(b'\0'*16),1,'i','',None,1)

if __name__=='__main__':unittest.main()
