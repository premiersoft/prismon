# Prismon Guardian (CLI)

Proxy HTTPS local para auditar chamadas de ferramentas LLM (desktop, web e CLIs de terminal) com guardrails e observabilidade centralizados.

## Instalação

A instalação é feita pelo TI, por máquina, via MDM (Intune, SCCM ou equivalente). Não há instalação manual nem auto-update: o MSI é o único caminho suportado e a versão nova chega pela distribuição do TI.

### Windows (MSI, Intune/SCCM)

Cada release em `https://github.com/premiersoft/prismon/releases` publica `prismon_<versão>_windows_amd64.msi` e `prismon_<versão>_checksums.txt` (confira o SHA-256 antes de subir o pacote). Quem administra a organização no Prismon gera um token de enrollment na tela Guardian (aba "Instalação"), que também entrega o comando pronto para colar no app Win32 do Intune:

```powershell
msiexec /i prismon_<versão>_windows_amd64.msi /qn /norestart REBOOT=ReallySuppress GATEWAY_URL=https://gateway.prismon.ai ENROLLMENT_TOKEN=pe-...
```

Propriedades: `GATEWAY_URL` (obrigatória), `ENROLLMENT_TOKEN` (token `pe-…` da tela Guardian) ou, como alternativa, `VIRTUAL_KEY` com uma key pronta. Detecção no Intune: `HKLM\SOFTWARE\Prismon`, valor `Version`, igual à versão do MSI. Ninguém precisa estar logado.

O MSI coloca o `prismon.exe` em `%ProgramFiles%\Prismon`, confia a CA no store da máquina e registra um Active Setup: no próximo logon de cada usuário o `prismon setup --unattended` roda sozinho, troca o token por uma virtual key da máquina e sobe o proxy sem perguntar nada. Para atualizar, publique o MSI novo com supersedência, sem desinstalar o anterior. Para remover, retire o app do dispositivo no Intune ou rode `msiexec /x {ProductCode}`: sai tudo, inclusive o que foi criado por usuário.

### macOS e Linux

Sem pacote de distribuição por enquanto. Instalações antigas feitas por script continuam funcionando, mas não recebem mais atualização automática.

## Uso

Depois do logon o proxy já está ativo como serviço de login. Use as ferramentas normalmente (Claude Desktop e navegadores; Claude Code, `codex`, `grok`, `agy` e `gemini` no terminal): o tráfego LLM é interceptado, avaliado pelos guardrails e registrado. Feche o app ou o navegador por completo e reabra depois do primeiro logon; só abrir não captura.

## Comandos

Rode num PowerShell novo depois do logon do usuário.

| Comando | Descrição |
|---|---|
| `prismon status` | confirma se o proxy está ON depois do logon (capturas, uptime, totais) |
| `prismon doctor` | diagnostica e repara a instalação (certificado, serviço de login, wrappers); `--export` salva relatório para suporte |
| `prismon matrix` | lista os apps e CLIs de IA homologados nesta instalação |
| `prismon version` | mostra a versão instalada; deve bater com o MSI no Intune |
| `prismon stop` | para o proxy e devolve o proxy de sistema; volta no próximo logon |
| `prismon setup --unattended` | repete o setup silencioso se o enrollment falhou, sem esperar o próximo logon |
| `prismon help` | mostra o uso |

Código-fonte: privado (monorepo). Este repositório contém apenas os binários e o MSI publicados.
