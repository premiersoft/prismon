<p align="center">
  <img src="assets/prismon-banner.png" alt="Prismon" width="720">
</p>

# Prismon Guardian (CLI)

Proxy HTTPS local para auditar chamadas de ferramentas LLM (desktop, web e CLIs de terminal) com guardrails e observabilidade centralizados.

## Instalação

A instalação é feita por máquina, com o MSI (Windows) ou o PKG (macOS). O caminho recomendado é o MDM (Intune, SCCM ou equivalente), que entrega a versão nova, reinstala e remove o Guardian em toda a frota. Para uma máquina avulsa, veja [Instalação manual](#instalação-manual-máquina-avulsa). Não há auto-update.

Cada release em `https://github.com/premiersoft/prismon/releases` publica os pacotes e `prismon_<versão>_checksums.txt`. Confira o SHA-256 antes de subir o pacote no MDM. Quem administra a organização no Prismon gera um token de enrollment na tela Guardian (aba "Instalação"); a própria aba entrega o comando do Windows e os perfis do macOS já preenchidos. Os pacotes públicos não contêm token nem credenciais.

### Windows (MSI, Intune/SCCM)

A release publica `prismon_<versão>_windows_amd64.msi`, `prismon_<versão>_windows_amd64.intunewin` e `uninstall.ps1`. Para **Windows app (Win32)** no Intune, envie diretamente o `.intunewin`: ele já contém o MSI e o `uninstall.ps1`. O MSI continua disponível para outros canais de distribuição. Comando de instalação:

```powershell
msiexec /i prismon_<versão>_windows_amd64.msi /qn /norestart REBOOT=ReallySuppress /l*v "%WINDIR%\Temp\prismon-msi-install.log" GATEWAY_URL=https://gateway.prismon.ai ENROLLMENT_TOKEN=pe-...
```

Propriedades: `GATEWAY_URL` (obrigatória), `ENROLLMENT_TOKEN` (token `pe-…` da tela Guardian) ou, como alternativa, `VIRTUAL_KEY` com uma key pronta. Comportamento de instalação: System. Detecção no Intune: `HKLM\SOFTWARE\Prismon`, valor `Version`, comparação de versão `>=` à versão do MSI, aplicativo de 64 bits. Ninguém precisa estar logado. Comando de desinstalação do app Win32: `powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1`.

O MSI coloca o `prismon.exe` em `%ProgramFiles%\Prismon`, confia a CA no store da máquina e registra um Active Setup: no próximo logon de cada usuário o `prismon setup --unattended` roda sozinho, troca o token por uma virtual key da máquina e sobe o proxy sem perguntar nada. Se o usuário já estiver logado durante a instalação, o setup é disparado na sessão dele na hora.

- **Atualizar:** publique o MSI novo com supersedência, sem desinstalar o anterior.
- **Remover:** retire o app do dispositivo no Intune ou rode `msiexec /x {ProductCode}`. Sai a camada de máquina e o que foi criado por usuário, mas o `~\.prismon` de cada perfil (virtual key e CA copiada) fica, para uma reinstalação não perder o vínculo. Para zerar a estação, rode `prismon machine cleanup --purge` elevado antes do `msiexec /x`.

### macOS (PKG, Intune)

A release publica `prismon_<versão>_darwin_universal.pkg` (Apple Silicon e Intel), assinado com Developer ID e notarizado pela Apple. Requer macOS 13 ou superior.

1. **App:** Intune → Apps → macOS → Add → **macOS app (PKG)**. Não use `macOS LOB app`: ele recusa pacotes que instalam fora de `/Applications` e trazem scripts de instalação. Deixe os campos de pre-install e post-install script vazios; o pacote já roda os dele. Requirements: macOS 13.0. Detection rules: `Ignore app version` = No e, em Included apps, o bundle `ai.prismon.guardian` com a versão do pacote. Assignment: Required, no grupo de dispositivos.
2. **Perfil com o token:** a aba "Instalação" gera o `ai.prismon.mobileconfig` com `GatewayUrl` e `EnrollmentToken`. Suba como perfil custom, canal de dispositivo, no mesmo grupo. É ele que leva o token ao Mac: o pacote é genérico e não precisa ser gerado por organização.
3. **Itens de Início de Sessão:** suba o `ai.prismon.loginitems.mobileconfig` (também na aba "Instalação") como segundo perfil custom, canal de dispositivo. Sem ele, o usuário consegue desligar o Guardian nos Ajustes do Sistema. Só instala por MDM.
4. **Certificado da organização (macOS 15+):** gere o certificado da organização na aba "Instalação" e distribua o `.cer` com um perfil **Trusted certificate** no mesmo grupo. Sem ele, alguém precisa aprovar o certificado em cada Mac.

O pacote instala o `prismon` em `/usr/local/bin`, um bundle mínimo em `/Applications/Prismon Guardian.app` (usado só pela regra de detecção do Intune) e a configuração de máquina em `/Library/Application Support/Prismon`. No login de cada usuário um LaunchAgent roda o `prismon setup --unattended`, faz o enrollment e sobe o proxy. Se o usuário já estiver logado durante a instalação, o setup começa em até 2 minutos, sem logout. Opcionalmente, um perfil custom no canal de **usuário** com `UserPrincipalName` = `{{userprincipalname}}` liga a máquina ao usuário Prismon pelo e-mail; sem ele, o admin atribui usuário e workspace na aba Clientes.

Em Mac onde o usuário não é administrador, o macOS não deixa trocar o proxy do sistema: o Guardian continua capturando o terminal e os apps que respeitam `HTTP_PROXY` (Claude Desktop incluso), mas não captura navegadores.

- **Atualizar:** publique o pacote novo como outro app, com assignment próprio, e retire o Required do app anterior. O pacote substitui a instalação anterior sozinho.
- **Remover:** o tipo `macOS app (PKG)` não tem assignment de Uninstall. Publique o [`uninstall.sh`](uninstall.sh) deste repositório como shell script do Intune (roda como root). Ele preserva o `~/.prismon` de cada perfil; `uninstall.sh --purge` apaga também.

### Instalação manual (máquina avulsa)

Para uma máquina fora do MDM, com uma conta de administrador nela. O token de enrollment sai da aba "Instalação", como no MDM.

- **Windows:** copie o MSI para `C:\Temp` e rode, num Prompt de Comando ou PowerShell elevado, o comando que a janela do token entrega (o mesmo `msiexec` acima, com `GATEWAY_URL` e `ENROLLMENT_TOKEN`). Só o duplo clique no MSI não basta: sem o token, o Guardian instala, mas não se registra. Quem já está logado é configurado na hora.
- **macOS:** no lugar do perfil com o token, grave a configuração de máquina com o comando que a janela do token entrega em "Instalar em um Mac sem o Intune", que cria `/Library/Application Support/Prismon/config.json` com `gatewayUrl` e `enrollmentToken`. Se a organização tem certificado próprio (necessário no macOS 15 ou superior), abra o `.cer` no Acesso às Chaves, adicione ao keychain Sistema e marque Sempre Confiar. Depois instale o pacote com duplo clique ou `sudo installer -pkg prismon_<versão>_darwin_universal.pkg -target /`. Sem o perfil do MDM, o Guardian não recebe o e-mail do usuário: atribua o usuário na aba Máquinas.

Sem o MDM, o Guardian não se atualiza nem é reinstalado sozinho. A cada versão nova, instale o pacote novo do mesmo jeito; o token fica gravado na máquina e não precisa ir de novo (no Windows, `msiexec /i <msi novo> /qn` elevado). No macOS, o perfil de Itens de Início de Sessão só instala por MDM, então o usuário consegue desligar o Guardian nos Ajustes do Sistema. Para remover, use Configurações › Aplicativos no Windows ou o [`uninstall.sh`](uninstall.sh) com `sudo` no macOS.

### Linux

Sem pacote de distribuição. Os `.tar.gz` da release existem para uso interno e não recebem suporte de instalação.

## Uso

Depois do logon o proxy já está ativo como serviço de login. Use as ferramentas normalmente (Claude Desktop, ChatGPT e navegadores; Claude Code, `codex`, `grok`, `agy` e `gemini` no terminal): o tráfego LLM é interceptado, avaliado pelos guardrails e registrado. Quando um guardrail bloqueia, o app recebe um erro e o Guardian mostra um alerta do sistema com o motivo.

Feche o app ou o navegador por completo (Cmd+Q no Mac; no Windows, saia do Chrome/Edge também pela bandeja) e reabra depois do primeiro logon. Só abrir não captura: envie uma mensagem e confira `Captured` em `prismon status`.

## Comandos

Rode num terminal novo (PowerShell no Windows, Terminal no macOS) depois do logon do usuário.

| Comando | Descrição |
|---|---|
| `prismon status` | confirma se o proxy está ON depois do logon (capturas, uptime, totais) |
| `prismon doctor` | diagnostica e repara a instalação (certificado, serviço de login, wrappers); `--export` salva relatório para suporte |
| `prismon matrix` | lista os apps e CLIs de IA homologados nesta instalação |
| `prismon version` | mostra a versão instalada; deve bater com o pacote no Intune |
| `prismon stop` | para o proxy e devolve o proxy de sistema; volta no próximo logon |
| `prismon setup --unattended` | repete o setup silencioso se o enrollment falhou, sem esperar o próximo logon |
| `prismon machine cleanup --purge` | zera a estação: apaga o `~/.prismon` de cada perfil, a CA dos stores e a config de máquina. Elevado no Windows, com `sudo` no macOS |
| `prismon help` | mostra o uso |

Código-fonte: privado. Este repositório contém apenas os binários, os pacotes publicados e os scripts de desinstalação.
