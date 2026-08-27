# Prismon CLI

Proxy HTTPS local para auditar chamadas de ferramentas LLM (desktop, web e CLIs de terminal) com guardrails e observabilidade centralizados.

## Instalação

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/premiersoft/prismon/main/install.sh | sh
```

- Valida o sha256 do release antes de instalar
- Instala em `~/.local/bin` (override: `PRISMON_INSTALL_DIR`) e adiciona esse diretório ao PATH do seu shell
- Versão específica: `PRISMON_VERSION=0.4.0 sh install.sh`

O instalador roda num processo filho e não altera o PATH do terminal que o chamou. Para usar `prismon` na mesma janela, rode o comando que ele imprime no final:

```bash
export PATH="$HOME/.local/bin:$PATH" && prismon
```

Em terminais abertos depois da instalação basta `prismon`.

É o mesmo layout que o auto-update usa, então o CLI passa a se manter atualizado sozinho.

### Windows (Path A — CLIs no terminal)

No PowerShell:

```powershell
irm https://raw.githubusercontent.com/premiersoft/prismon/main/install.ps1 | iex
```

- Valida o sha256 do release antes de instalar
- Instala em `%LOCALAPPDATA%\prismon` e adiciona esse diretório ao PATH do usuário
- Versão específica: `$env:PRISMON_VERSION='0.4.0'; irm ... | iex`

Depois rode `prismon` nesse terminal: ele pede a virtual key, instala a CA no store do usuário (confirme o diálogo do Windows), sobe o proxy como serviço de login e liga o proxy de sistema (WinINET) para desktop e navegador que respeitam o proxy do Windows. Não precisa deixar o terminal aberto. Use `claude`, `codex`, `grok`, `agy` ou `gemini` em qualquer terminal novo. No Windows, Claude Code (CLI, via wrapper), Codex CLI, Grok CLI, Antigravity (`agy`), Claude Desktop, Claude Web, ChatGPT Web (visitante), Gemini Web e Lovable Web estão homologados — feche o app ou o navegador por completo (Claude Desktop pela bandeja), reabra e envie uma mensagem; só abrir não captura. A primeira execução pede UAC para instalar a CA no store da máquina (necessário para o Claude Desktop da Microsoft Store). Apps com certificate pinning ou que ignoram o proxy do SO continuam fora.

### Já instalou por Homebrew?

O tap `leozanchett/prismon` foi descontinuado e está congelado numa versão antiga: `brew upgrade prismon` não traz mais atualizações. Instalação por brew também não participa do auto-update — o binário fica no Cellar, que o `prismon update` não substitui, e o CLI recusa a atualização em vez de deixar o terminal numa versão e o serviço em outra.

Para migrar:

```bash
brew uninstall prismon
curl -fsSL https://raw.githubusercontent.com/premiersoft/prismon/main/install.sh | sh
prismon
```

## Uso

```bash
prismon   # primeira execução: configura a virtual key, instala a CA local e os aliases de CLIs
```

No macOS e no Windows o proxy passa a rodar como serviço de login — sobe sozinho a cada login, sem terminal aberto — e o auto-update é ativado. No Windows os CLIs entram pelos wrappers e o desktop/web entra pelo proxy de sistema (WinINET/WinHTTP), quando o app respeita o proxy do SO.

Depois disso, use as ferramentas normalmente (Claude Desktop e navegadores no macOS e no Windows; Claude Code, grok, codex, agy e gemini no terminal) — o tráfego LLM é interceptado, avaliado pelos guardrails e registrado.

## Comandos

| Comando | Descrição |
|---|---|
| `prismon` | configura o CLI e ativa o serviço em segundo plano e o auto-update |
| `prismon status` | snapshot da sessão ativa (status, capturas, uptime, totais) |
| `prismon matrix` | lista os apps e CLIs de IA homologados |
| `prismon stop` | para o serviço (ele volta no próximo login) |
| `prismon doctor` | diagnóstico do ambiente, com auto-correção de estados degradados |
| `prismon config` | altera a virtual key salva |
| `prismon update` | atualiza para a última versão agora (`--check` apenas verifica) |
| `prismon updater` | controla o auto-update de hora em hora (`install`/`status`/`uninstall`) |
| `prismon service` | controla o serviço em segundo plano (`install`/`start`/`stop`/`status`/`uninstall`) |
| `prismon version` | mostra a versão instalada |
| `prismon help` | mostra o uso |

Código-fonte: privado (monorepo). Este repositório contém apenas os binários publicados e o instalador.
