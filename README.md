# Memória Studio

Um aplicativo independente para Windows, criado do zero, com interface própria em português do Brasil. Não usa o Cheat Engine e não modifica sua instalação.

![Interface real do novo aplicativo, renderizada no ambiente de desenvolvimento](docs/interface.png)

## Baixar

**[Baixar Memória Studio para Windows](https://github.com/Leandroxx10/testerea/releases/download/memoria-studio-1/MemoriaStudio-Windows.zip)**

Extraia o ZIP inteiro em uma pasta própria e abra `MemoriaStudio.exe`. O executável não exige Python instalado nem usa arquivos do Cheat Engine. Mantenha a pasta `_internal` ao lado dele.

```bat
curl.exe --fail -L "https://github.com/Leandroxx10/testerea/releases/download/memoria-studio-1/MemoriaStudio-Windows.zip" -o "%USERPROFILE%\Downloads\MemoriaStudio-Windows.zip"
```

- [Prévia real da interface](docs/interface.png).
- [Código-fonte pronto para iniciar](downloads/MemoriaStudio-Fonte.zip): alternativa com Python 3.12 x64 e `Iniciar.cmd`.
- [Compilação e testes do Windows](https://github.com/Leandroxx10/testerea/actions/runs/41545842189).
- [SHA-256 do executável empacotado](downloads/MemoriaStudio-Windows.sha256).

A implementação e os limites estão descritos no [guia do aplicativo](standalone/LEIA-ME.md).

## Remover a extensão anterior do Cheat Engine

Feche o Cheat Engine e remova **somente** os arquivos criados pela extensão anterior:

```text
C:\Program Files\Cheat Engine\autorun\ce_modern.lua
C:\Program Files\Cheat Engine\autorun\ce_modern\
```

Não apague a pasta `autorun` nem os demais scripts. Se personalizou os arquivos acima, copie-os antes. Reabra o CE: as mudanças visuais da extensão eram feitas durante a execução. Os instaladores anteriores não substituíam os executáveis do programa. As pastas `CE-Modern-backup-*` preservam versões anteriores da própria extensão; restaurá-las reativaria a extensão.

Os pacotes antigos foram retirados dos downloads. O código histórico está em `legacy/ce-modern`, sem uso pelo novo app.

## Estado da entrega

Busca numérica, refinamento, cancelamento, endereços salvos, edição/congelamento, projetos próprios, leitura hexadecimal, desmontagem x64 e comandos de voz pt-BR foram implementados. A voz depende do microfone e do reconhecedor local do Windows. Não há suporte a `.CT`, depurador, drivers, Auto Assembler ou scripts nesta primeira versão independente.

A interface foi renderizada e inspecionada no Linux. Os testes de busca e interface passaram no Linux e no fluxo Windows. O teste nativo de leitura/escrita, listagem de processos e regiões de memória passou no Windows antes da compilação. O pacote publicado foi baixado e sua integridade ZIP foi conferida. O microfone ainda precisa ser testado no computador de destino.
