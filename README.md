# CE Modern 0.2.0 — espaço integrado em português do Brasil

Interface guiada para a instalação Windows do Cheat Engine. O painel usa o mecanismo real do programa: os processos, buscas, resultados e registros não são dados de demonstração.

## Download pelo CMD

Baixe o assistente atualizado pelo CMD **ja aberto**:

```bat
curl.exe --fail -L "https://raw.githubusercontent.com/Leandroxx10/testerea/main/downloads/Baixar-CE-Modern.cmd" -o "%USERPROFILE%\Downloads\Baixar-CE-Modern.cmd"
call "%USERPROFILE%\Downloads\Baixar-CE-Modern.cmd"
```

Ou baixe [Baixar-CE-Modern.cmd](downloads/Baixar-CE-Modern.cmd) e execute por duplo clique. O assistente baixa o ZIP, verifica o SHA-256, extrai todos os arquivos e chama o instalador. A janela permanece aberta para mostrar erros; nao e necessario desativar verificacao TLS, checksum ou politica do PowerShell.

Se o destino for `C:\Program Files\Cheat Engine`, execute o assistente como administrador. A instalacao padrao e detectada pelo caminho; se nao existir, o instalador pede a pasta correta. Pode ser, por exemplo, `C:\Program Files\Cheat Engine 7.5`.

**Instalar.cmd nao faz download:** ele instala os arquivos que ja estao extraidos ao seu lado. Nao execute o instalador diretamente de dentro do ZIP nem copie apenas esse arquivo. Feche o Cheat Engine antes da instalacao.

Logs: `%USERPROFILE%\Downloads\CE-Modern-Setup\download.log` para download, checksum e extracao; `%LOCALAPPDATA%\CE-Modern\instalacao.log` para copias e permissoes. Se houver erro, envie o texto mostrado ou o log correspondente.

Para baixar somente o ZIP:

```bat
curl.exe --fail -L "https://raw.githubusercontent.com/Leandroxx10/testerea/main/downloads/CE-Modern-Windows.zip" -o "%USERPROFILE%\Downloads\CE-Modern-Windows.zip"
```

Extraia tudo e execute `CE-Modern\Instalar.cmd`. O instalador atualiza apenas os quatro arquivos da extensao, preserva outros scripts e faz uma copia da versao anterior. E possivel tambem copiar o conteudo da pasta `autorun` manualmente para a instalacao do Cheat Engine.

## O que funciona dentro do painel

| Área | Operações implementadas |
| --- | --- |
| Conectar aplicativo | Listagem e filtro de processos reais, conexão por PID |
| Busca guiada | Busca inicial e refinamento, seis tipos numéricos, oito comparações, limpeza e até 500 resultados visíveis |
| Resultados | Total encontrado e adição do endereço selecionado à tabela real |
| Minha tabela | Nome, endereço e valor; congelar/descongelar; excluir; abrir e salvar `.CT` |
| Memória | Leitura de 128 bytes e desmontagem de 30 instruções por endereço ou símbolo |
| Scripts | Editor Lua/Auto Assembler, abrir/salvar código e execução com confirmação |
| Recursos avançados | Tentativa de incorporar a área original do Cheat Engine no painel |
| Ajuda | Passo a passo e frases de voz em pt-BR |

As buscas rodam no `MemScan` do Cheat Engine, sem bloquear a navegação. Os resultados são lidos somente após a conclusão. O tipo de dado é preservado ao refinar, e o painel bloqueia buscas simultâneas e troca de processo durante uma busca. Se houver mais de 500 resultados, refine para reduzir a lista; o total completo é informado.

Comece pelo aplicativo de tutorial da sua instalação: conecte seu processo, escolha **Inteiro • 4 bytes**, informe um valor conhecido e clique **Primeira busca**. Mude o valor no tutorial, informe o novo número e clique **Refinar busca**. Adicione o resultado desejado e abra **Minha tabela**.

Congelar é exclusivo de registros de valores. Scripts e grupos não são ativados por esse botão. Descongele o registro antes de alterar seu endereço ou valor. Tabelas `.CT` são mescladas para preservar os registros atuais; o Cheat Engine mantém seus diálogos habituais para o conteúdo desses arquivos.

## Voz em português do Brasil

Clique **Ativar / parar voz** e aguarde **OUVINDO EM PORTUGUÊS**. O microfone permanece desligado até esse clique.

| Frase | Ação |
| --- | --- |
| Selecionar processo | Abre o seletor integrado |
| Primeira busca | Solicita confirmação e inicia a busca |
| Próxima busca | Solicita confirmação e refina |
| Abrir tabela | Navega para a tabela |
| Abrir memória | Navega para memória |
| Abrir scripts | Navega para o editor |
| Abrir ajuda | Mostra a ajuda |
| Interface original | Abre Recursos avançados dentro do painel |
| Parar escuta | Interrompe a sessão de voz |

Requer Windows PowerShell 5.1, um microfone padrão e um reconhecedor **pt-BR compatível com `System.Speech`** instalado. O idioma de exibição ou uma voz de leitura de texto não garantem que esse reconhecedor exista. Não há fallback para português de Portugal. A extensão informa quando o reconhecedor está ausente.

O reconhecimento usa a API de fala local do Windows; a extensão não envia áudio para APIs de nuvem. O serviço aceita somente as nove frases e exige confiança mínima de 80%. Texto falado nunca é avaliado como código. Fechar o assistente interrompe a voz; uma sessão dura no máximo duas horas.

A política do PowerShell precisa permitir executar `autorun\ce_modern\voice.ps1`. O instalador não altera essa política. Se o serviço não iniciar em vinte segundos, o painel informa o problema; as demais funções continuam disponíveis.

## Limitações e estado da validação

Esta entrega continua sendo uma extensão, que depende do Cheat Engine instalado, não um executável independente. Não redistribui os executáveis e DLLs enviados.

O fluxo principal foi reimplementado em pt-BR dentro do painel. A área **Recursos avançados** reutiliza os controles da instalação existente: seus textos seguem a tradução instalada no próprio Cheat Engine, e certas ferramentas podem abrir diálogos próprios. Não é uma retradução completa de cada módulo do Cheat Engine. A incorporação de janelas depende da versão e do comportamento do Lazarus no Windows.

**Ainda não houve teste real no Windows, renderização nativa ou teste de microfone.** Não é possível garantir todas as operações no seu computador com base nos testes de contrato realizados no Linux. Falhas devem ser diagnosticadas a partir da mensagem exata e da versão do Cheat Engine.

Verificado no ambiente de desenvolvimento:

- 11 verificações do roteamento e consumo de comandos.
- 20 verificações do adaptador de processos, buscas assíncronas, resultados, tabela e limpeza de recursos.
- Fluxo integrado com objetos simulados: seleção, busca, resultados, congelamento, bytes, desmontagem, scripts, incorporação, confirmação de voz e encerramento.
- Correspondência dos nove comandos entre Lua/PowerShell e codificação compatível com Windows PowerShell 5.1.

Para repetir os testes:

```sh
luatex --luaonly tests/core.test.lua
luatex --luaonly tests/engine.test.lua
luatex --luaonly tests/ui.test.lua
python3 tests/voice_contract.py
```

No Windows, execute os fluxos acima com o tutorial do Cheat Engine e teste as frases **abrir ajuda**, **próxima busca** (cancelando e confirmando) e **parar escuta**. O serviço de voz, instaladores e controles nativos exigem essa validação adicional.

## Remover

Feche o Cheat Engine. Exclua somente `autorun\ce_modern.lua` e a subpasta `autorun\ce_modern`. Se houve atualização, os arquivos anteriores ficam na pasta `CE-Modern-backup-*` criada dentro da instalação.
