# Endurecimento da VPS

Guia do endurecimento aplicado na VPS que hospeda o `ai-memory`. Todos os
valores sensiveis sao placeholders (`<TAILNET_IP>`, `<VPS_HOSTNAME>`,
`<TAILNET_FQDN>`, `<SERVICE_PORT>`). Troque pelos seus.

## 1. Rede: tailnet-only, zero porta publica

Instalar Tailscale e subir:

```bash
tailscale up --ssh=false --hostname=<VPS_HOSTNAME>
```

Firewall com `ufw`, default-deny de entrada. Libera SSH e a porta do servico
**somente** na interface `tailscale0`:

```bash
ufw default deny incoming
ufw default allow outgoing

# SSH e o servico so pela tailnet:
ufw allow in on tailscale0 to any port 22 proto tcp
ufw allow in on tailscale0 to any port <SERVICE_PORT> proto tcp

ufw enable
```

Nenhuma regra libera porta na interface publica. A internet nao enxerga o SSH
nem o servico.

## 2. Acesso: SSH key-only + fail2ban

`/etc/ssh/sshd_config.d/hardening.conf`:

```
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
```

```bash
systemctl restart ssh
apt-get install -y fail2ban
systemctl enable --now fail2ban
```

## 3. Patches automaticos

```bash
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

## 4. Processo: usuario sem privilegio + sandbox systemd

Usuario dedicado e data-dir:

```bash
adduser --system --group aimem
mkdir -p /opt/ai-memory /var/lib/ai-memory
chown -R aimem:aimem /var/lib/ai-memory
```

A unit `systemd/ai-memory.service` roda como esse usuario com sandbox:
`NoNewPrivileges`, `ProtectSystem=strict`, `CapabilityBoundingSet` vazio e
`ReadWritePaths` = so o data-dir. Ver a unit para a lista completa.

## 5. Token e allowed_hosts

Token bearer protege toda rota menos `/health`. Guardar fora do repo, modo 600:

```bash
install -d -m 700 -o aimem -g aimem /etc/ai-memory
# grava o token (nunca commitar este arquivo):
printf 'AIMEM_TOKEN=%s\n' "<SEU_TOKEN>" > /etc/ai-memory/token.env
chmod 600 /etc/ai-memory/token.env
chown aimem:aimem /etc/ai-memory/token.env
```

`AIMEM_ALLOWED_HOSTS=<TAILNET_FQDN>` rejeita requisicoes com Host diferente,
mitigando DNS-rebinding.

## 6. Subir o servico

```bash
cp systemd/ai-memory.service /etc/systemd/system/
cp systemd/aimem-digest.service /etc/systemd/system/
cp systemd/aimem-digest.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now ai-memory.service
systemctl enable --now aimem-digest.timer
```

Conferir que escuta so na tailnet:

```bash
ss -tlnp | grep <SERVICE_PORT>   # deve mostrar <TAILNET_IP>, nunca 0.0.0.0
```

## 7. Recuperacao

Se a tailnet cair, o SSH via tailnet some junto. Acesso de emergencia =
**console VNC do painel da VPS** (fora do Tailscale). Nunca abrir SSH na
interface publica como contingencia.
