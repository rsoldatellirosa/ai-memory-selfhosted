# ai-memory self-hosted (caso real sanitizado)

Caso de migração de um servidor de **memória de longo prazo compartilhada entre
agentes de IA** (Claude Code + Codex), que rodava localmente no Windows, para
uma **VPS Linux endurecida e acessível apenas por rede privada Tailscale**.

> **Aviso:** repositório de referência. Todos os valores sensíveis (IP,
> hostname/FQDN, token, chave SSH) são **placeholders**. Nada aqui contém dado
> real de produção.

---

## O problema

A stack usa o projeto open source [`ai-memory`](https://github.com/akitaonrails/ai-memory)
(de akitaonrails) como memória persistente cruzando vários projetos. Os agentes
leem e escrevem notas, decisões e gotchas via MCP.

O servidor rodava **local no Windows** como binário nativo. A partir de um
Windows Update, o **Smart App Control** passou a bloquear o executável por não
ter assinatura de código reconhecida. Desligar o Smart App Control é uma
operação **irreversível** (só volta com reinstalação limpa do Windows), então
não era opção. Resultado: o servidor local morreu e a memória ficou
indisponível para os agentes.

## A solução

Migrar o servidor para uma **VPS Linux (Ubuntu)**, exposta **somente** pela
tailnet (rede privada Tailscale). Nenhuma porta pública aberta. O binário roda
em Linux, onde não existe o gate de assinatura do Smart App Control.

## Arquitetura

```
┌───────────────────────┐         tailnet (WireGuard)        ┌────────────────────────┐
│  Estação de trabalho   │  ───────────────────────────────▶ │  VPS Ubuntu            │
│  (Claude Code / Codex) │   100.x.x.x  <TAILNET_FQDN>        │  ai-memory (systemd)   │
│  cliente MCP           │ ◀───────────────────────────────  │  usuário sem privilégio│
└───────────────────────┘        só interface tailscale0     └────────────────────────┘
```

- **Transporte:** Tailscale (WireGuard). O serviço escuta só na interface
  `tailscale0`; a internet pública não enxerga a porta.
- **Processo:** unit `systemd` como usuário dedicado sem privilégio, com sandbox
  (ver `systemd/ai-memory.service`).
- **Dados:** diretório de dados próprio, único caminho com escrita permitida.
- **Digest diário:** timer `systemd` gera um resumo cruzando os projetos
  (ver `systemd/aimem-digest.*` + `scripts/aimem-digest.sh`).

## Segurança (endurecimento)

Detalhe completo em [`docs/hardening.md`](docs/hardening.md). Resumo das camadas:

| Camada | Medida |
|--------|--------|
| Rede | `ufw` default-deny de entrada; SSH e a porta do serviço **só** em `tailscale0`; nenhuma porta pública |
| Acesso | SSH key-only (sem senha); `fail2ban` |
| Patches | `unattended-upgrades` ligado |
| Processo | `systemd` como usuário sem privilégio: `NoNewPrivileges`, `ProtectSystem=strict`, `CapabilityBoundingSet` vazio, `ReadWritePaths` só o data-dir |
| App | token bearer em toda rota (exceto healthcheck); `allowed_hosts` contra DNS-rebinding |

Segredos (token, caminho de chave) nunca ficam no repositório nem na unit: a
unit lê o token de um arquivo fora do controle de versão via
`$(cat /caminho/do/token)` / `EnvironmentFile`.

## Modo de operação

- **Leitura:** ligada e automática (os agentes consultam a memória via MCP).
- **Escrita:** **manual** via MCP. A captura automática por hooks está
  **desligada** — os hooks locais chamavam o binário que o Smart App Control
  bloqueava, então foram desativados para não quebrar as sessões. Escrita
  durável acontece só quando o usuário pede explicitamente.
- **Digest:** rotina diária (timer `systemd`) cruza os projetos e grava um
  resumo.

## Recuperação

Se a tailnet cair e o SSH via tailnet ficar inacessível, o acesso de emergência
é o **console VNC do painel da VPS** (fora da rede Tailscale). Por isso o
console do provedor continua sendo o caminho de resgate — nunca abrir SSH na
interface pública como "plano B".

## Lição

- Binário nativo sem assinatura em Windows com Smart App Control = risco de
  parada súbita e **irreversível**. Para serviço que precisa ficar de pé, Linux
  endurecido é mais previsível.
- Tailnet-only (zero porta pública) + sandbox `systemd` dá uma superfície de
  ataque mínima com pouquíssima configuração.
- Separar **transporte** (Tailscale), **processo** (sandbox systemd) e
  **aplicação** (token + allowed_hosts) deixa cada camada simples e auditável.

---

## EN (short)

Shared long-term memory for AI agents (Claude Code + Codex) using the open
source `ai-memory` project. It ran locally on Windows until Smart App Control
started blocking the unsigned binary (irreversible to disable). Migrated to a
hardened Ubuntu VPS reachable **only** over a Tailscale tailnet — no public
ports. Hardening: `ufw` default-deny, SSH and the service port bound to
`tailscale0` only, `fail2ban`, `unattended-upgrades`, key-only SSH, a sandboxed
`systemd` unit (unprivileged user, `NoNewPrivileges`, `ProtectSystem=strict`,
empty `CapabilityBoundingSet`, `ReadWritePaths` = data dir only), bearer token
on every route but healthcheck, and `allowed_hosts` against DNS rebinding.
Operation is read + manual write via MCP (auto-capture off). A daily systemd
timer builds a cross-project digest. Recovery if the tailnet is down = the VPS
panel's VNC console. All sensitive values in this repo are placeholders.

## Licença

MIT — ver [`LICENSE`](LICENSE).
