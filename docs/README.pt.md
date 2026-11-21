# OpenNodeDesk para macOS

**Um hub de conexões remotas local-first para macOS.** Mantenha cada servidor, conta e parâmetro de
conexão em uma única lista pesquisável, reutilizável e portátil — e vá de "preciso daquela máquina"
até uma sessão ao vivo em três passos.

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · **[Português]** · [Русский](README.ru.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [Tiếng Việt](README.vi.md)

Versão atual: **v2.3.5**

---

## O que é

O OpenNodeDesk não é mais um cliente de desktop remoto. A renderização da tela remota, o
redirecionamento de periféricos e o áudio/vídeo ficam por conta do cliente mais maduro da
plataforma — o Microsoft Windows App para RDP, o Compartilhamento de Tela integrado para VNC e um
terminal integrado para SSH. O OpenNodeDesk cuida dos **outros 90%**: o inventário, os parâmetros,
as credenciais, os lembretes de expiração e o histórico de conexões.

Princípios de design:

- **Conexão em três segundos** — pesquise, pressione Return e a sessão abre.
- **Local primeiro, funciona offline, sem conta** — abra, pesquise, edite e conecte sem rede.
- **Não reinvente a roda** — a renderização remota pertence ao melhor cliente da plataforma.
- **Parâmetros explicáveis** — cada valor efetivo é rotulado como *personalizado / template /
  padrão*.
- **Falhas explicáveis** — os erros vêm com uma causa e sugestões acionáveis, nunca com um código
  bruto.
- **Dados portáteis** — exporte e importe com um clique; migre de máquina com um único arquivo.
- **Teclado primeiro** — toda ação principal tem um atalho.

## Recursos

### Central de ativos
- Layouts de tabela e grade; busca por nome, host, grupo, proprietário e notas.
- Favoritos, conexões recentes e grupos recolhíveis na barra lateral.
- Mostrar/ocultar e reordenar por coluna, além de um tamanho de fonte global para a lista.
- Lembretes de expiração: ativos que expiram em até 30 dias (ou já expirados) são sinalizados no
  próprio lugar.
- Detecção de duplicatas por **host + porta** na importação.

### RDP / SSH / VNC
- Portas padrão por protocolo (3389 / 22 / 5900), com substituição livre.
- **RDP** — gera um arquivo `.rdp` temporário para o Microsoft Windows App; modo de janela,
  profundidade de cor, redirecionamento de unidade/áudio/área de transferência e resolução são
  todos configuráveis. Os binários do FreeRDP são detectados e iniciados diretamente com a senha
  armazenada, pulando a solicitação de credenciais. O preenchimento automático de senha na caixa de
  diálogo de credenciais do Windows App usa a API de Acessibilidade do macOS.
- **VNC** — usa o Compartilhamento de Tela integrado por padrão; visualizadores externos (RealVNC,
  TigerVNC…) podem ser configurados com um template de argumentos de inicialização com suporte a
  `{host} {port} {display} {user} {password}`.
- **SSH** — um terminal de verdade incorporado ao aplicativo (SwiftTerm), com jump host (`-J`),
  autenticação por chave privada, suporte a passphrase de chave e argumentos `ssh` extras
  configuráveis.

### Templates de conexão
Conjuntos de parâmetros reutilizáveis (protocolo, porta, nome de usuário, redirecionamento, modo de
janela, profundidade de cor, tamanho da janela SSH). Cada parâmetro resolvido mostra seu valor
atual **e de onde ele veio**.

### Espaço de trabalho de sessões
- Várias sessões lado a lado com layouts divididos alternáveis e maximização por sessão.
- Uma caixa "abrir ativo" na barra de ferramentas: digite um nome ou host e pressione Return, ou
  escolha na lista.
- Janelas SSH separadas são suportadas quando você prefere mantê-las fora do espaço de trabalho.

### Transferência de arquivos SFTP
- Navegador de arquivos remotos completo por ativo: diretórios, tamanhos, permissões, horários de
  modificação.
- Envie e baixe arquivos ou pastas inteiras, com retomada (`reput` / `reget`).
- Crie pastas, exclua arquivos ou pastas vazias, arraste e solte arquivos na pasta atual.
- Disponível na barra de ferramentas da sessão e no menu de contexto do terminal SSH.

### Menu de contexto do terminal SSH
Copiar, colar, selecionar tudo e "transferência de arquivos" bem onde você está digitando. Quando
um programa remoto captura o mouse (vim, tmux), o clique com o botão direito é repassado ao programa
remoto conforme o esperado.

### Credenciais
- Senhas e passphrases de chave são armazenadas **somente** no Keychain do macOS, nunca nos arquivos
  de dados.
- Excluir um ativo ou desmarcar "lembrar senha" remove a entrada do Keychain.

### Importação, exportação e sincronização
- Importe de CSV ou Excel (`.xlsx`) com mapeamento automático de colunas e uma prévia de validação.
- Exporte para CSV ou JSON, com seleção por campo; campos sensíveis ficam desmarcados por padrão.
- A sincronização na nuvem puxa uma prévia primeiro e mescla apenas o que você selecionar — somente
  ativos e templates, nunca senhas.

### Verificação de alcance
Sondagem TCP de ativos individuais, da seleção ou de todo o inventário, sob demanda ou por
temporizador.

### Bloqueio do app (passphrase de proteção)
- Bloqueio opcional por passphrase com auto-bloqueio ocioso (1–60 minutos).
- Hash da passphrase com **PBKDF2-SHA256**, 100 000 iterações e um salt aleatório de 128 bits.
- Um código de recuperação é emitido uma única vez na configuração (Crockford Base32, tolerante a
  `O/0`, `I/L/1`).
- Configurável: após 5 falhas consecutivas, apague automaticamente os dados locais, ou permaneça
  bloqueado e exija uma limpeza manual.

### Aparência e ajuda
- Tema Seguir o Sistema / Claro / Escuro; interface em chinês simplificado e inglês.
- Um manual de ajuda dentro do app cobrindo o uso de VNC, solução de problemas por protocolo,
  localização dos dados e privacidade das credenciais.

## Requisitos

| Item | Requisito |
| --- | --- |
| macOS | 14.0 (Sonoma) ou posterior |
| Portador de RDP | Microsoft Windows App (da App Store) |
| Portador de VNC | Compartilhamento de Tela integrado, ou RealVNC / TigerVNC e similares |
| Preenchimento automático de senha RDP | Permissão de Acessibilidade para o OpenNodeDesk |
| Compilar a partir do código-fonte | Xcode 16 ou posterior (toolchain Swift 6) |

## Instalação

1. Baixe `OpenNodeDesk-<version>-macos.zip` da página de
   [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases).
2. Descompacte e arraste `OpenNodeDesk.app` para `/Applications`.
3. A build não é notarizada pela Apple, então o Gatekeeper pode avisar na primeira inicialização —
   clique com o botão direito no app e escolha **Abrir**, ou permita em *Ajustes do Sistema →
   Privacidade e Segurança*.

## Compilar a partir do código-fonte

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release build + dist/OpenNodeDesk.app
make run      # build, bundle and launch
```

Alvos úteis: `make check` (compila e mostra diagnósticos), `make clean` (descarta `.build` e
`dist`), `make reset` (remove os dados locais de `~/Library/Application Support/RemotePilot`).

## Estrutura do projeto

```
Sources/RemotePilot/
├── App/            App entry point, global model, commands and menus
├── Core/           SSH/SFTP, Keychain, probing, import/export, sync, carrier detection, RDP auto-fill
├── Design/         Design tokens and shared components
├── Localization/   Chinese source strings + English string table
├── Models/         Asset, template, settings and runtime models
├── Views/          Sidebar, asset center, workspace, sessions, settings, help, dialogs
└── main.swift      Entry point (also serves as the SSH_ASKPASS helper)
Resources/          Info.plist and app icon
docs/              Design documents and translated READMEs
```

## Dados e privacidade

- Ativos, templates e configurações ficam em `~/Library/Application Support/RemotePilot`
  (`assets.json`, `settings.json`).
- Senhas e passphrases de chave são gravadas somente no Keychain do macOS; elas nunca fazem parte de
  uma exportação ou de um payload de sincronização. Portanto, migrar para outra máquina exige
  digitá-las novamente.
- O app funciona totalmente offline; o endpoint de sincronização na nuvem é opcional e fornecido
  pelo usuário.

## Observações e limitações

- O Windows App do macOS não consegue hospedar várias sessões como abas em uma única janela; optar
  pelo modo de janela em abas abre uma janela normal. Use o espaço de trabalho de sessões para
  várias sessões.
- Se nenhum portador de RDP estiver instalado, as tentativas de conexão explicam o que instalar e
  onde.
- O identificador de bundle interno `com.remotepilot.macos` e o diretório de dados `RemotePilot`
  permanecem intencionalmente inalterados desde a renomeação, para que ativos, configurações e
  entradas do Keychain existentes continuem funcionando após a atualização.

## Documentação

- [Design de produto e UX](PRODUCT_UX_DESIGN.md)
- [Delta de design](PRODUCT_UX_DESIGN_DELTA.md)
- [Bloqueio por passphrase e auto-bloqueio ocioso](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
