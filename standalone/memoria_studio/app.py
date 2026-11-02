import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import traceback
from PySide6.QtCore import Qt, QThread, Signal, QTimer, QProcess
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QFrame, QLineEdit, QComboBox, QTableWidget, QTableWidgetItem,
    QHeaderView, QSizePolicy, QStackedWidget, QDialog, QListWidget, QFileDialog, QMessageBox, QCheckBox, QPlainTextEdit)
from .native import WindowsMemory
from .scanner import TYPES, MODES, encode, decode, scan

STYLE = '''
QWidget {font-family: "Segoe UI", "DejaVu Sans"; font-size: 13px; color: #23324a;}
QMainWindow, #body {background: #f4f7fb;}
#sidebar {background: #112237; border: none;}
#sidebar QLabel {color: #9bafc6; background: transparent;}
#sidebar #brand {color: #f5fbff; font-size: 20px; font-weight: 700;}
#sidebar QPushButton {text-align:left; color: #b9c9da; background: transparent; border: none; padding: 14px; border-radius: 8px;}
#sidebar QPushButton:hover {background: #1b344e;}
#sidebar QPushButton:checked {background: #23435d; color: #ffffff; font-weight: 600;}
QPushButton {background: white; border: 1px solid #dce3ec; border-radius: 8px; padding: 10px 16px; font-weight: 600;}
QPushButton:hover {background: #eaf2f6; border-color:#b0c5cf;}
QPushButton:disabled {color: #97a5b6; background: #edf1f5;}
QPushButton#primary {background: #087e75; color: white; border-color: #087e75;}
QPushButton#primary:hover {background: #06675f;}
QPushButton#primary:disabled {background: #accbc7; border-color: #accbc7;}
#title {font-size: 29px; font-weight:700; color: #17283e;}
#subtitle {color:#6f7f93; font-size:14px;}
#eyebrow {color:#087e75; font-size:11px; font-weight:700;}
#card {background:white; border:1px solid #e2e8f0; border-radius:12px;}
#card QLabel {background:transparent;}
#notice {padding:12px 16px; border-radius:8px; background:#e5f2ef; color:#236158;}
QLineEdit, QComboBox, QPlainTextEdit {background: white; border:1px solid #d9e2ed; border-radius:7px; padding:10px; selection-background-color:#c1e5dd;}
QLineEdit:focus, QComboBox:focus {border:1px solid #087e75;}
QTableWidget {background:white; border:none; gridline-color:#eef2f7; alternate-background-color:#f8fafc; selection-background-color:#e0f0ec; selection-color:#14382e;}
QTableWidget::item {padding:10px;}
QHeaderView::section {background:#f7f9fc; color:#718196; padding:12px; border:none; border-bottom:1px solid #e7edf4; font-weight:600;}
QDialog {background:#f4f7fb;} QListWidget {background:white; border:1px solid #dce3ec; border-radius:8px; padding:8px;}
QListWidget::item {padding:12px; border-radius:5px;}
QListWidget::item:selected {background:#dceee9; color:#164d42;}
QPlainTextEdit {font-family:Consolas,"DejaVu Sans Mono"; font-size:12px;}
'''

class ScanWorker(QThread):
    completed = Signal(object, bool)
    failure = Signal(str)
    progress = Signal(object)
    def __init__(self, memory, pid, kind, value, previous, mode):
        super().__init__(); self.arguments = memory, pid, kind, value, previous, mode
    def run(self):
        try:
            result, limited = scan(*self.arguments, cancelled=self.isInterruptionRequested, progress=self.progress.emit)
            self.completed.emit(result, limited)
        except Exception as error:
            self.failure.emit(str(error))

def button(text, action, primary=False):
    b = QPushButton(text); b.setCursor(Qt.PointingHandCursor)
    if primary: b.setObjectName('primary')
    b.clicked.connect(action); return b

def card():
    w = QFrame(); w.setObjectName('card'); layout = QVBoxLayout(w)
    layout.setContentsMargins(22, 20, 22, 20); layout.setSpacing(16); return w, layout

def table(headers):
    t = QTableWidget(0, len(headers)); t.setHorizontalHeaderLabels(headers)
    t.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
    t.verticalHeader().hide(); t.verticalHeader().setDefaultSectionSize(46)
    t.setAlternatingRowColors(True); t.setSelectionBehavior(QTableWidget.SelectRows)
    t.setEditTriggers(QTableWidget.NoEditTriggers); return t

class Window(QMainWindow):
    def __init__(self, memory=None):
        super().__init__()
        self.setWindowTitle('Memória Studio'); self.resize(1260, 850); self.setMinimumSize(1080, 720)
        self.pid = None; self.process_name = ''; self.results = {}; self.result_kind = None; self.saved = []
        self.worker = None; self.voice_process = None; self.voice_temp = None; self.voice_sequence = 0
        try: self.memory = memory or WindowsMemory(); self.platform_error = ''
        except OSError as error: self.memory = None; self.platform_error = str(error)
        root = QWidget(); self.setCentralWidget(root); layout = QHBoxLayout(root); layout.setContentsMargins(0,0,0,0); layout.setSpacing(0)
        sidebar = QFrame(); sidebar.setObjectName('sidebar'); sidebar.setFixedWidth(264)
        side = QVBoxLayout(sidebar); side.setContentsMargins(18,28,18,22); side.setSpacing(9)
        brand = QLabel('memória / studio'); brand.setObjectName('brand'); side.addWidget(brand)
        tagline=QLabel('Um novo espaço para explorar.');tagline.setWordWrap(True);side.addWidget(tagline); side.addSpacing(42)
        self.nav = []
        for i, name in enumerate(['01   Busca de valores', '02   Meus endereços', '03   Memória', '04   Ajuda e voz']):
            b = button(name, lambda checked=False, index=i: self.navigate(index)); b.setCheckable(True); side.addWidget(b); self.nav.append(b)
        side.addStretch(); side.addWidget(QLabel('APLICATIVO INDEPENDENTE'))
        note = QLabel('Instalação independente.\nSem arquivos na pasta do CE.'); note.setWordWrap(True); side.addWidget(note); side.addSpacing(18)
        self.voice_button = button('Ativar voz', self.toggle_voice); side.addWidget(self.voice_button)
        layout.addWidget(sidebar)
        body = QWidget(); body.setObjectName('body'); body_layout = QVBoxLayout(body); body_layout.setContentsMargins(34,28,34,24); body_layout.setSpacing(22)
        top = QHBoxLayout(); crumb = QLabel('ÁREA DE TRABALHO  /  PORTUGUÊS BRASIL'); crumb.setObjectName('eyebrow'); top.addWidget(crumb); top.addStretch()
        self.process_button = button('Conectar aplicativo', self.choose_process); top.addWidget(self.process_button); body_layout.addLayout(top)
        self.stack = QStackedWidget(); body_layout.addWidget(self.stack, 1)
        self.notice = QLabel('Tudo começa por um processo. Clique em “Conectar aplicativo” para escolher.'); self.notice.setWordWrap(True); self.notice.setObjectName('notice'); body_layout.addWidget(self.notice)
        layout.addWidget(body,1)
        self.make_scan(); self.make_saved(); self.make_memory(); self.make_help(); self.navigate(0)
        self.freeze_timer = QTimer(self); self.freeze_timer.timeout.connect(self.freeze_tick); self.freeze_timer.start(750)
        self.voice_timer = QTimer(self); self.voice_timer.timeout.connect(self.poll_voice)

    def page(self, title, subtitle):
        w = QWidget(); layout = QVBoxLayout(w); layout.setContentsMargins(0,0,0,0); layout.setSpacing(20)
        h = QLabel(title); h.setObjectName('title');h.setWordWrap(True); layout.addWidget(h)
        s = QLabel(subtitle); s.setObjectName('subtitle'); s.setWordWrap(True); layout.addWidget(s)
        self.stack.addWidget(w); return layout

    def navigate(self, index):
        self.stack.setCurrentIndex(index)
        for i,b in enumerate(self.nav): b.setChecked(i==index)
        if index==1: self.render_saved()

    def report(self, text): self.notice.setText(str(text))
    def guard(self, fn):
        try: return fn()
        except Exception as error: self.report(str(error)); return None
    def require_process(self):
        if not self.pid: raise ValueError('Conecte um aplicativo antes de continuar.')
    def confirm(self, text):
        dialog = QMessageBox(self); dialog.setWindowTitle('Confirmar ação'); dialog.setText(text)
        yes = dialog.addButton('Confirmar', QMessageBox.AcceptRole); dialog.addButton('Cancelar', QMessageBox.RejectRole)
        dialog.exec(); return dialog.clickedButton()==yes

    def choose_process(self): self.guard(self._choose_process)
    def _choose_process(self):
        if self.worker and self.worker.isRunning(): raise ValueError('Cancele ou aguarde a busca antes de trocar o processo.')
        if self.memory is None: raise OSError(self.platform_error)
        rows = self.memory.processes()
        d = QDialog(self); d.setWindowTitle('Conectar aplicativo'); d.resize(620,530); v = QVBoxLayout(d); v.setSpacing(16)
        v.addWidget(QLabel('Escolha o programa que você quer analisar.'))
        search = QLineEdit(); search.setPlaceholderText('Pesquisar pelo nome ou PID…'); v.addWidget(search)
        items = QListWidget(); v.addWidget(items)
        def refresh():
            items.clear()
            for p in rows:
                if search.text().casefold() in f'{p.name} {p.pid}'.casefold():
                    from PySide6.QtWidgets import QListWidgetItem
                    item=QListWidgetItem(f'{p.name}     ·     PID {p.pid}'); item.setData(Qt.UserRole,p); items.addItem(item)
        def connect():
            item=items.currentItem()
            if not item: return
            p=item.data(Qt.UserRole)
            try:
                with self.memory.handle(p.pid): pass
            except Exception as error: self.report(error); return
            if self.saved and not self.confirm('Trocar de processo vai limpar os resultados e endereços desta sessão. Continuar?'): return
            self.pid=p.pid; self.process_name=p.name; self.results={}; self.saved=[]; self.result_kind=None
            self.process_button.setText(f'{p.name}  ·  {p.pid}'); self.render_results(); self.render_saved(); d.accept(); self.report('Conectado. Informe um valor conhecido para começar.'); self.navigate(0)
        search.textChanged.connect(refresh); refresh(); v.addWidget(button('Conectar ao aplicativo',connect,True)); d.exec()

    def make_scan(self):
        layout=self.page('Encontre o valor. Veja o que muda.', 'Um fluxo simples: conecte o aplicativo, busque um valor e refine os resultados.')
        c,v=card(); step=QLabel('1  CONECTAR     →     2  BUSCAR     →     3  REFINAR');step.setObjectName('eyebrow');v.addWidget(step)
        fields=QHBoxLayout(); fields.setSpacing(18)
        self.value=QLineEdit();self.value.setPlaceholderText('Ex.: 100');self.value.setMinimumWidth(140)
        self.kind=QComboBox();self.kind.addItems(TYPES)
        self.mode=QComboBox();self.mode.addItems(MODES)
        for combo in (self.kind,self.mode):combo.setSizeAdjustPolicy(QComboBox.AdjustToMinimumContentsLengthWithIcon);combo.setMinimumContentsLength(12)
        for title,w in [('Valor que aparece no aplicativo',self.value),('Tipo de dado',self.kind),('Comparação',self.mode)]:
            f=QVBoxLayout();caption=QLabel(title);caption.setWordWrap(True);f.addWidget(caption);w.setSizePolicy(QSizePolicy.Expanding,QSizePolicy.Fixed);f.addWidget(w);fields.addLayout(f,1)
        v.addLayout(fields)
        actions=QHBoxLayout();self.first_button=button('Primeira busca',lambda:self.start_scan(False),True)
        self.next_button=button('Refinar resultados',lambda:self.start_scan(True));self.cancel_button=button('Cancelar busca',self.cancel_scan);self.cancel_button.setEnabled(False)
        actions.addWidget(self.first_button);actions.addWidget(self.next_button);actions.addStretch();actions.addWidget(self.cancel_button);v.addLayout(actions)
        help_label=QLabel('Não sabe qual tipo escolher? Comece com Inteiro · 4 bytes para valores inteiros.');help_label.setObjectName('subtitle');help_label.setWordWrap(True);v.addWidget(help_label);layout.addWidget(c)
        c,v=card();bar=QHBoxLayout();self.result_label=QLabel('RESULTADOS');self.result_label.setObjectName('eyebrow');bar.addWidget(self.result_label);bar.addStretch();bar.addWidget(button('Salvar endereço selecionado',self.save_result));v.addLayout(bar)
        self.result_table=table(['Endereço','Valor encontrado','Tipo']);self.result_table.setMinimumHeight(250)
        self.empty=QLabel('Sua busca começa aqui\n\nOs endereços encontrados aparecerão nesta área.');self.empty.setAlignment(Qt.AlignCenter);self.empty.setMinimumHeight(250);self.empty.setObjectName('subtitle')
        self.result_views=QStackedWidget();self.result_views.addWidget(self.empty);self.result_views.addWidget(self.result_table);v.addWidget(self.result_views);layout.addWidget(c,1)

    def start_scan(self, refine): self.guard(lambda:self._start_scan(refine))
    def _start_scan(self, refine):
        self.require_process()
        if self.worker and self.worker.isRunning(): raise ValueError('Uma busca já está em andamento.')
        kind=TYPES[self.kind.currentText()]
        if refine and self.result_kind is None: raise ValueError('Faça uma primeira busca antes de refinar.')
        if refine and kind!=self.result_kind: raise ValueError('Mantenha o tipo de dado da primeira busca ou inicie outra.')
        mode=self.mode.currentIndex()
        if mode==0: encode(self.value.text(),kind)
        if not refine and mode: raise ValueError('Na primeira busca, escolha “Igual ao valor”. As outras opções comparam resultados anteriores.')
        self.pending_kind=kind
        self.worker=ScanWorker(self.memory,self.pid,kind,self.value.text(),dict(self.results) if refine else None,mode)
        self.worker.completed.connect(self.scan_done);self.worker.failure.connect(self.report)
        self.worker.progress.connect(lambda n:self.report(f'Buscando… {n:,} '+('endereços verificados.' if refine else 'bytes verificados.')))
        self.worker.finished.connect(self.scan_finished);self.first_button.setEnabled(False);self.next_button.setEnabled(False);self.cancel_button.setEnabled(True)
        self.report('Busca iniciada. Você pode navegar pelas outras áreas.');self.worker.start()
    def scan_done(self, results, limited):
        self.results=results;self.result_kind=self.pending_kind;self.render_results()
        self.report(f'{len(results):,} endereços encontrados.'+(' Limite de 100 mil atingido: a busca foi interrompida; o refinamento usará apenas esses candidatos.' if limited else ''))
    def scan_finished(self): self.first_button.setEnabled(True);self.next_button.setEnabled(True);self.cancel_button.setEnabled(False)
    def cancel_scan(self):
        if self.worker and self.worker.isRunning():self.worker.requestInterruption();self.report('Cancelando… Os resultados anteriores serão preservados.')
    def render_results(self):
        rows=list(self.results.items())[:500];self.visible_results=rows;self.result_table.setRowCount(len(rows))
        for row,(address,value) in enumerate(rows):
            for col,text in enumerate([f'{address:016X}',str(value),next((n for n,k in TYPES.items() if k==self.result_kind),'')]):self.result_table.setItem(row,col,QTableWidgetItem(text))
        self.result_label.setText(f'{len(self.results):,} RESULTADOS · EXIBINDO ATÉ 500');self.result_views.setCurrentIndex(1 if rows else 0)
    def save_result(self):
        row=self.result_table.currentRow()
        if row<0:self.report('Selecione uma linha dos resultados para salvar.');return
        address,value=self.visible_results[row]
        self.saved.append({'name':'Novo endereço','address':address,'value':str(value),'kind':self.result_kind,'frozen':False})
        self.render_saved();self.report('Endereço salvo. Abra “Meus endereços” para editar seu nome e valor.')

    def make_saved(self):
        layout=self.page('Seus endereços, bem organizados.', 'Dê um nome a cada descoberta e acompanhe os valores sem perder o contexto.')
        bar=QHBoxLayout();bar.addWidget(button('Atualizar valores',self.refresh_values));bar.addWidget(button('Abrir projeto',self.open_project));bar.addWidget(button('Salvar projeto',self.save_project));bar.addStretch();bar.addWidget(button('Remover selecionado',self.remove_record));layout.addLayout(bar)
        c,v=card();self.saved_table=table(['Congelar','Nome','Endereço','Valor','Editar']);v.addWidget(self.saved_table);layout.addWidget(c,1)
        hint=QLabel('Congelar mantém o valor atual. Desmarque para liberar. Projetos usam o formato próprio .json.');hint.setWordWrap(True);hint.setObjectName('subtitle');layout.addWidget(hint)
    def render_saved(self):
        self.saved_table.setRowCount(len(self.saved))
        for row,record in enumerate(self.saved):
            check=QCheckBox('Manter valor');check.setChecked(record['frozen']);check.clicked.connect(lambda checked,r=record:self.toggle_frozen(r,checked));self.saved_table.setCellWidget(row,0,check)
            for col,key in [(1,'name'),(2,'address'),(3,'value')]:self.saved_table.setItem(row,col,QTableWidgetItem(f'{record[key]:X}' if key=='address' else str(record[key])))
            self.saved_table.setCellWidget(row,4,button('Editar',lambda checked=False,r=record:self.edit_record(r)))
    def edit_record(self,record):
        d=QDialog(self);d.setWindowTitle('Editar endereço');v=QVBoxLayout(d);d.setMinimumWidth(420)
        name=QLineEdit(record['name']);address=QLineEdit(f'{record["address"]:X}');value=QLineEdit(record['value'])
        for title,w in [('Nome para lembrar','Endereço hexadecimal','Novo valor')]:v.addWidget(QLabel(title));v.addWidget(w)
        def apply():
            def operation():
                self.require_process()
                if record['frozen']:raise ValueError('Descongele o endereço antes de editar.')
                target=int(address.text(),16);data=encode(value.text(),record['kind'])
                if not self.confirm('Escrever o novo valor no processo conectado?'):return
                self.memory.write(self.pid,target,data);record.update(name=name.text(),address=target,value=value.text());d.accept();self.render_saved();self.report('Valor atualizado no processo.')
            self.guard(operation)
        v.addWidget(button('Aplicar ao processo',apply,True));d.exec()
    def toggle_frozen(self,record,checked):
        if checked and (not self.pid or not self.confirm('Manter este valor fixo no processo conectado?')):self.render_saved();return
        record['frozen']=checked
    def freeze_tick(self):
        if not self.pid:return
        for record in self.saved:
            if record['frozen']:
                try:self.memory.write(self.pid,record['address'],encode(record['value'],record['kind']))
                except Exception as error:record['frozen']=False;self.report('Congelamento interrompido: '+str(error));self.render_saved()
    def refresh_values(self):
        def operation():
            self.require_process()
            for r in self.saved:r['value']=str(decode(self.memory.read(self.pid,r['address'],struct.calcsize('<'+r['kind'])),r['kind']))
            self.render_saved();self.report('Valores atualizados.')
        self.guard(operation)
    def remove_record(self):
        row=self.saved_table.currentRow()
        if row>=0:self.saved.pop(row);self.render_saved()
    def save_project(self):
        path,_=QFileDialog.getSaveFileName(self,'Salvar projeto','','Projeto Memória Studio (*.json)')
        if path:self.guard(lambda:Path(path).write_text(json.dumps({'version':1,'process':self.process_name,'records':[dict(r,frozen=False) for r in self.saved]},ensure_ascii=False,indent=2),encoding='utf-8'))
    def open_project(self):
        path,_=QFileDialog.getOpenFileName(self,'Abrir projeto','','Projeto Memória Studio (*.json)')
        if not path:return
        def operation():
            payload=json.loads(Path(path).read_text(encoding='utf-8'));assert payload.get('version')==1,'Formato de projeto incompatível.'
            records=payload['records'];assert isinstance(records,list) and len(records)<=10000,'Projeto grande ou inválido.'
            clean=[]
            for r in records:
                assert r['kind'] in TYPES.values() and isinstance(r['address'],int) and 0<=r['address']<2**64,'Endereço ou tipo inválido.'
                encode(r['value'],r['kind']);clean.append(dict(name=str(r['name']),address=r['address'],value=str(r['value']),kind=r['kind'],frozen=False))
            if self.saved and not self.confirm('Substituir a lista de endereços desta sessão?'):return
            self.saved=clean;self.render_saved();self.report('Projeto aberto. Os valores não foram escritos nem congelados. Confira o processo e os endereços antes de aplicar alterações.')
        self.guard(operation)

    def make_memory(self):
        layout=self.page('Explore a memória com clareza.', 'Leia dados em hexadecimal ou veja as instruções do endereço escolhido.')
        c,v=card();bar=QHBoxLayout();self.address=QLineEdit();self.address.setPlaceholderText('Endereço hexadecimal · exemplo: 7FF612340000');bar.addWidget(self.address,1)
        bar.addWidget(button('Ler 256 bytes',lambda:self.read_memory(False),True));bar.addWidget(button('Ver instruções x64',lambda:self.read_memory(True)));v.addLayout(bar)
        self.memory_output=QPlainTextEdit();self.memory_output.setReadOnly(True);self.memory_output.setPlaceholderText('Os dados lidos do processo aparecerão aqui.');v.addWidget(self.memory_output,1);layout.addWidget(c,1)
    def read_memory(self,instructions):
        def operation():
            self.require_process();address=int(self.address.text(),16);data=self.memory.read(self.pid,address,256)
            if instructions:
                from capstone import Cs, CS_ARCH_X86, CS_MODE_64
                lines=[f'{i.address:016X}  {i.mnemonic:8s} {i.op_str}' for i in Cs(CS_ARCH_X86,CS_MODE_64).disasm(data,address)]
            else:
                lines=[f'{address+i:016X}  {data[i:i+16].hex(" ").upper():47s}  '+''.join(chr(b) if 32<=b<=126 else '.' for b in data[i:i+16]) for i in range(0,len(data),16)]
            self.memory_output.setPlainText('\n'.join(lines));self.report('Leitura concluída. Nenhum valor foi alterado.')
        self.guard(operation)

    def make_help(self):
        layout=self.page('Você não precisa adivinhar o próximo passo.', 'Ajuda em português do Brasil, sempre ao alcance.')
        c,v=card()
        for title,body in [
          ('01  Conecte um aplicativo','Escolha o programa que deseja analisar. O Memória Studio não usa nem altera arquivos do Cheat Engine.'),
          ('02  Encontre e refine','Informe um valor conhecido e use Primeira busca. Altere-o no aplicativo e refine. Para comparar mudanças, escolha Valor mudou, aumentou ou diminuiu.'),
          ('03  Salve o que importa','Salve um resultado, dê um nome e consulte Meus endereços. A edição e o congelamento só escrevem valores após uma ação explícita.'),
          ('Comandos de voz em pt-BR','Conectar aplicativo · Primeira busca · Refinar busca · Abrir endereços · Abrir memória · Abrir ajuda · Parar escuta.'),
          ('Como ativar a voz','Clique no botão da barra lateral. É necessário um microfone e um reconhecedor pt-BR compatível com System.Speech no Windows. O programa informa se ele estiver ausente.')]:
            t=QLabel(title);t.setStyleSheet('font-size:15px;font-weight:600;');v.addWidget(t);b=QLabel(body);b.setWordWrap(True);b.setObjectName('subtitle');v.addWidget(b)
        layout.addWidget(c);layout.addStretch()

    def toggle_voice(self):
        if self.voice_process and self.voice_process.state()!=QProcess.NotRunning:self.stop_voice();return
        if os.name!='nt':self.report('A voz local está disponível no Windows com reconhecedor pt-BR instalado.');return
        self.voice_temp=tempfile.TemporaryDirectory(prefix='memoria-studio-');self.voice_session=Path(self.voice_temp.name)/'session';self.voice_sequence=0
        self.voice_process=QProcess(self)
        ps=Path(os.environ.get('SystemRoot','C:\\Windows'))/'System32/WindowsPowerShell/v1.0/powershell.exe'
        self.voice_process.errorOccurred.connect(self.voice_error)
        self.voice_process.finished.connect(self.voice_finished)
        self.voice_process.start(str(ps),['-NoProfile','-File',str(Path(__file__).with_name('voice.ps1')),'-SessionPath',str(self.voice_session)])
        self.voice_timer.start(350);self.voice_elapsed=0;self.voice_ready=False;self.voice_button.setText('Parar voz');self.report('Iniciando o microfone…')
    def voice_error(self,error):
        if self.voice_process.state()==QProcess.NotRunning:self.voice_finished()
        self.report('Não foi possível iniciar o serviço de voz. Confira o Windows PowerShell e a política de execução.')
    def stop_voice(self):
        if self.voice_temp:Path(str(self.voice_session)+'.stop').write_text('stop')
        self.voice_button.setText('Encerrando escuta…')
    def voice_finished(self):
        self.voice_timer.stop();self.voice_button.setText('Ativar voz')
        if self.voice_temp:
            status=Path(str(self.voice_session)+'.status')
            try: state=status.read_text(encoding='utf-8-sig')
            except OSError: state=''
            if state=='missing-locale':self.report('Reconhecedor pt-BR ausente no Windows. Os botões continuam disponíveis.')
            elif state=='error':self.report('Falha no microfone ou no reconhecimento de fala do Windows.')
            elif state=='':self.report('O serviço de voz não iniciou. Confira a política do PowerShell e o microfone.')
        if self.voice_temp:self.voice_temp.cleanup();self.voice_temp=None
    def poll_voice(self):
        self.voice_elapsed+=350;status=Path(str(self.voice_session)+'.status')
        if status.exists():
            try:state=status.read_text(encoding='utf-8-sig')
            except OSError:return
            if state=='ready' and not self.voice_ready:self.voice_ready=True;self.report('Ouvindo em português do Brasil. Diga “abrir ajuda”.')
            elif state=='missing-locale':self.report('Reconhecedor pt-BR ausente no Windows. Instale um mecanismo de reconhecimento compatível com System.Speech.');self.stop_voice()
            elif state=='error':self.report('Falha no microfone ou no reconhecedor do Windows. Confira o dispositivo padrão e suas permissões.');self.stop_voice()
        elif self.voice_elapsed>20000:self.report('O serviço de voz não iniciou. Confira as permissões de microfone e a política do PowerShell.');self.stop_voice()
        events=Path(str(self.voice_session)+'.events')
        if not events.exists():return
        try:lines=events.read_text(encoding='ascii').splitlines()
        except OSError:return
        for line in lines:
            try:number,token=line.split('|');number=int(number)
            except ValueError:continue
            if number<=self.voice_sequence:continue
            self.voice_sequence=number
            actions={'process':self.choose_process,'table':lambda:self.navigate(1),'memory':lambda:self.navigate(2),'help':lambda:self.navigate(3),'stop':self.stop_voice}
            if token in actions:actions[token]()
            elif token in ('scan','next') and self.confirm('Executar uma busca com os valores mostrados na tela?'):self.navigate(0);self.start_scan(token=='next')
            if token=='stop':break
    def closeEvent(self,event):
        if self.worker and self.worker.isRunning():self.cancel_scan();self.report('Aguarde o cancelamento e feche a janela novamente.');event.ignore();return
        self.saved=[];self.stop_voice()
        if self.voice_process and not self.voice_process.waitForFinished(1800):self.voice_process.terminate();self.voice_process.waitForFinished(1000)
        event.accept()

def main():
    app=QApplication(sys.argv);app.setApplicationName('Memória Studio');app.setStyle('Fusion');app.setStyleSheet(STYLE)
    window=Window();window.show();return app.exec()

if __name__=='__main__':sys.exit(main())
