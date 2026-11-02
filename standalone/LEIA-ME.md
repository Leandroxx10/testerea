# Memória Studio — aplicativo independente

Este é um novo projeto, escrito do zero com Python, Qt e a API de processos do Windows. Não usa o Cheat Engine, não carrega DLLs dele e não instala nada na sua pasta.

## Abrir

Extraia o ZIP em uma pasta própria, como `Downloads\MemoriaStudio`. Se o pacote contiver `MemoriaStudio.exe`, abra esse executável. No pacote de código-fonte, abra `Iniciar.cmd`: ele usa Python 3.12 de 64 bits para criar um ambiente `.venv` apenas nessa pasta e instalar as dependências. Não execute de dentro do ZIP.

O pacote de código-fonte requer Python 3.12 x64 instalado. O iniciador exibe a instrução para instalar se ele estiver ausente. A janela de diagnóstico permanece aberta caso haja erro.

## O que foi implementado

- Interface própria em pt-BR: busca, endereços, memória e ajuda.
- Listagem e conexão a processos pela API nativa do Windows.
- Busca inicial por número conhecido: inteiros assinados de 1, 2, 4 e 8 bytes; decimais simples e duplos.
- Refinar por igualdade, alteração, sem alteração, aumento ou diminuição.
- Busca em segundo plano com cancelamento; até 100 mil candidatos e 500 resultados visíveis. Se o limite for atingido, o painel informa que a busca não percorreu toda a memória.
- Endereços salvos: editar valor/endereço/nome, congelar e liberar.
- Projetos `.json` próprios; abrir não escreve nem congela valores automaticamente.
- Leitura hexadecimal e desmontagem x64 com Capstone.
- Sete comandos de voz locais em pt-BR, sem usar serviços de nuvem. Requer reconhecedor `System.Speech` pt-BR e microfone no Windows; o programa informa quando o recurso estiver indisponível. Não altera a política do PowerShell.

O tipo de dado não pode mudar ao refinar. Uma busca cancelada preserva os candidatos anteriores. Trocar de processo limpa os endereços após confirmação. Congelar começa somente após ação explícita e para ao fechar o app ou quando uma escrita falhar.

## Escopo e validação

É uma primeira versão independente, não uma implementação de todos os recursos avançados do Cheat Engine. Não inclui drivers, depurador, Auto Assembler, importação de tabelas `.CT` ou editor de scripts. Esses recursos não aparecem como botões que redirecionam para outro programa.

O código de busca e o fluxo da interface são testados automaticamente. A interface foi renderizada e inspecionada no Linux. Um teste específico do Windows verifica leitura/escrita/listagem/regiões usando somente a memória do próprio processo de teste; ele é ignorado em outros sistemas. A voz exige teste com o microfone real.

Para testes: `python -m unittest discover -s tests -v`, com a raiz deste pacote no `PYTHONPATH`. No ambiente Linux sem tela, use `QT_QPA_PLATFORM=offscreen`.

## Remover a extensão anterior do CE

1. Feche o Cheat Engine.
2. Na pasta `C:\Program Files\Cheat Engine\autorun`, remova **somente** `ce_modern.lua` e a subpasta `ce_modern` criados pelo pacote anterior. Não apague a pasta `autorun` nem os outros scripts.
3. Reabra o Cheat Engine. A mudança de interface da extensão existia durante a execução; o novo app não precisa dela.

Se você personalizou esses arquivos, copie-os antes de remover. As pastas `CE-Modern-backup-*` continham versões anteriores da própria extensão. Não restaure uma delas se quiser remover a extensão por completo.

Os instaladores anteriores não substituíam os executáveis do CE. Se você identificar outras alterações fora desses quatro arquivos, envie os caminhos para investigar antes de remover qualquer coisa.
