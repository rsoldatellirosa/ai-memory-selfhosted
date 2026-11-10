# ai-memory self-hosted

Minha instância self-hosted do [`ai-memory`](https://github.com/akitaonrails/ai-memory)
(projeto open source de akitaonrails): **memória de longo prazo compartilhada
entre meus agentes de IA** (Claude Code + Codex), rodando numa **VPS Linux
acessível apenas pela rede privada Tailscale**.

Este repositório é um **caso de uso + referência de setup**: como eu organizo a
memória, como os agentes consomem, e como eu hospedo o servidor de forma
endurecida. Não é um produto — é a minha configuração, documentada.

> **Aviso:** valores sensíveis (IP, hostname/FQDN, token, chave SSH) são
> **placeholders**. Nada aqui contém dado real de produção.

---

## O que é

`ai-memory` dá aos agentes uma **memória persistente que cruza vários projetos**.
Em vez de cada sessão começar do zero, os agentes:

- **leem** histórico, decisões, convenções e *gotchas* de cada projeto;
- **escrevem** páginas duráveis de conhecimento (wiki por projeto);
- fazem *recall* por busca full-text + entidades;
- passam contexto entre si via *handoff*.

Tudo por **MCP**, então o mesmo acervo de memória é compartilhado entre clientes
diferentes.

## Por que eu uso

Trabalho com **dois agentes** no mesmo conjunto de projetos — Claude Code e
Codex. Sem memória compartilhada, cada um reaprende as mesmas coisas a cada
sessão e as decisões se perdem. Com um servidor `ai-memory` único:

- os dois agentes leem e escrevem o **mesmo** acervo;
- cada projeto tem um *overview* curado (stack, infra, estado, decisões);
- o que descobri numa sessão continua disponível na próxima, em qualquer agente.

## Como eu uso (fluxo)

- **Clientes:** Claude Code e Codex apontam o MCP para o servidor.
- **Leitura:** automática — os agentes consultam a memória ao longo da sessão.
- **Escrita durável:** **manual**, só quando eu peço explicitamente para
  lembrar algo (evita ruído de captura automática).
- **Organização:** uma página de *overview* por projeto + páginas de regras,
  decisões e gotchas.
- **Digest diário:** um timer `systemd` gera um resumo cruzando os projetos
  (ver `scripts/aimem-digest.sh` + `systemd/aimem-digest.*`).

## Onde roda

Servidor numa **VPS Ubuntu**, exposto **somente** pela tailnet (Tailscale /
WireGuard). Nenhuma porta pública.

> Antes rodava local na minha estação; migrei para a VPS por previsibilidade —
> um serviço que precisa ficar de pé fica mais estável num Linux endurecido e
> dedicado do que preso ao ciclo de atualização e aos gates de assinatura do
> desktop.

```
┌───────────────────────┐         tailnet (WireGuard)        ┌────────────────────────┐
│  Estação de trabalho   │  ───────────────────────────────▶ │  VPS Ubuntu            │
│  (Claude Code / Codex) │   100.x.x.x  <TAILNET_FQDN>        │  ai-memory (systemd)   │
│  cliente MCP           │ ◀───────────────────────────────  │  usuário sem privilégio│
└───────────────────────┘        só interface tailscale0     └────────────────────────┘
```

- **Transporte:** Tailscale. O serviço escuta só em `tailscale0`; a internet
  pública não enxerga a porta.
- **Processo:** unit `systemd` como usuário dedicado sem privilégio, com sandbox
  (ver `systemd/ai-memory.service`).
- **Dados:** diretório próprio, único caminho com escrita permitida.

## Setup

O passo a passo do servidor está em [`docs/hardening.md`](docs/hardening.md)
(rede, acesso, patches, sandbox do processo, token, subir o serviço). Os
arquivos de apoio:

- `systemd/ai-memory.service` — unit endurecida do servidor.
- `systemd/aimem-digest.service` + `.timer` — rotina do digest diário.
- `scripts/aimem-digest.sh` — script do digest.

## Segurança (endurecimento)

Detalhe em [`docs/hardening.md`](docs/hardening.md). Camadas:

| Camada | Medida |
|--------|--------|
| Rede | `ufw` default-deny de entrada; SSH e a porta do serviço **só** em `tailscale0`; nenhuma porta pública |
| Acesso | SSH key-only (sem senha); `fail2ban` |
| Patches | `unattended-upgrades` ligado |
| Processo | `systemd` como usuário sem privilégio: `NoNewPrivileges`, `ProtectSystem=strict`, `CapabilityBoundingSet` vazio, `ReadWritePaths` só o data-dir |
| App | token bearer em toda rota (exceto healthcheck); `allowed_hosts` contra DNS-rebinding |

Segredos (token, caminho de chave) nunca ficam no repositório nem na unit: o
token é lido de um arquivo fora do controle de versão (`EnvironmentFile`).

Separar **transporte** (Tailscale), **processo** (sandbox systemd) e
**aplicação** (token + `allowed_hosts`) deixa cada camada simples e auditável,
com superfície de ataque pública igual a zero.

## Recuperação

Se a tailnet cair e o SSH via tailnet ficar inacessível, o acesso de emergência
é o **console VNC do painel da VPS** (fora do Tailscale). Por isso nunca abro SSH
na interface pública como "plano B".

---

## EN (short)

My self-hosted instance of the open source `ai-memory` project: **shared
long-term memory for my AI agents** (Claude Code + Codex), running on a Linux
VPS reachable **only** over a Tailscale tailnet. A use case + setup reference,
not a product.

Why: I run two agents over the same set of projects; a single shared memory
server means both read and write the same store, each project keeps a curated
overview, and what I learn in one session survives into the next, in any agent.
Reads are automatic; durable writes are manual via MCP; a daily `systemd` timer
builds a cross-project digest.

Hardening: `ufw` default-deny, SSH and the service port bound to `tailscale0`
only, `fail2ban`, `unattended-upgrades`, key-only SSH, a sandboxed `systemd`
unit (unprivileged user, `NoNewPrivileges`, `ProtectSystem=strict`, empty
`CapabilityBoundingSet`, `ReadWritePaths` = data dir only), bearer token on
every route but healthcheck, and `allowed_hosts` against DNS rebinding. Public
attack surface is zero. Recovery if the tailnet is down = the VPS panel's VNC
console. All sensitive values here are placeholders.

## Licença

MIT — ver [`LICENSE`](LICENSE).
