import unittest
from PySide6.QtWidgets import QApplication
from memoria_studio.app import Window, STYLE
from memoria_studio.scanner import encode
from test_scanner import Memory

class UITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app=QApplication.instance() or QApplication([]);cls.app.setStyleSheet(STYLE)
    def test_independent_window_and_real_scan_worker(self):
        memory=Memory(encode(100,'i')+encode(20,'i'));window=Window(memory);window.show();self.app.processEvents()
        window.start_scan(False);self.assertIn('Conecte',window.notice.text())
        window.pid=1;window.value.setText('100');window.start_scan(False)
        from PySide6.QtCore import QEventLoop,QTimer
        loop=QEventLoop();window.worker.finished.connect(loop.quit);QTimer.singleShot(5000,loop.quit);loop.exec();self.app.processEvents()
        self.assertEqual(window.results,{0x1000:100});window.result_table.selectRow(0);window.save_result();self.assertEqual(len(window.saved),1)
        window.navigate(1);self.assertEqual(window.saved_table.rowCount(),1)
        window.navigate(2);window.address.setText('1000');memory.read=lambda pid,address,size:encode(100,'i')
        window.read_memory(False);self.assertIn('64 00 00 00',window.memory_output.toPlainText())
        window.navigate(3);self.assertIsNone(window.voice_process);window.close()
    def test_failed_refinement_preserves_results(self):
        window=Window(Memory(b''));window.pid=1;window.results={1:100};window.result_kind='i';window.kind.setCurrentIndex(1)
        window.start_scan(True);self.assertEqual(window.results,{1:100});self.assertIn('tipo',window.notice.text());window.close()

if __name__=='__main__':unittest.main()
