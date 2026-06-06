# Let's Encrypt TLS Pipeline: Certbot DNS-01 → Freebox OS

Automatic renewal of a Let's Encrypt certificate and deployment to Freebox OS, with no manual intervention.
Code from a real operational case, anonymized and adapted for publication.

```
Certbot (DNS-01 via Infomaniak)
→ Let's Encrypt RSA certificate
→ import into Freebox OS (fbx-delta-nba_bash_api.sh)
→ TLS verification from outside
```

> ⚠️ The Freebox certificate import relies on undocumented API endpoints. A Freebox OS update may break this workflow.

## Tested context

| Item | Value |
|---|---|
| DNS | Infomaniak |
| ACME challenge | DNS-01 |
| Certbot | Isolated Python venv |
| Certificate | RSA 2048 bits |
| Freebox API | fbx-delta-nba_bash_api.sh |
| Machine | Raspberry Pi / Debian LAN |

## Structure

```
letsencrypt-cert-pipeline/
├── config/
│   ├── freebox-cert.env.example
│   ├── infomaniak.ini.example
│   └── cert-audit.hosts.example
├── scripts/
│   ├── install-prereqs.sh         # one-off setup
│   ├── install-freebox-api-lib.sh # one-off setup
│   ├── authorize-freebox-app.sh   # one-off setup
│   ├── certbot-renew-infomaniak   # installed in sbin/, called by cron
│   ├── deploy-cert-to-freebox     # installed in sbin/, called by cron
│   ├── check-freebox-cert         # installed in sbin/, called by cron
│   └── audit-cert-expiry.sh       # on-demand audit
└── docs/
    ├── OPERATING_PROCEDURE.md
    └── TROUBLESHOOTING.md
```

Scripts meant to be installed in `/usr/local/sbin/` and called as system commands have no extension (Unix convention). One-off scripts keep the `.sh` extension.

## Installation

### System dependencies

```bash
sudo scripts/install-prereqs.sh
```

### Freebox API library

Downloads [fbx-delta-nba_bash_api.sh](https://github.com/nbanb/fbx-delta-nba_bash_api.sh) from the original repository and installs it in `/opt/freebox-api/`.

```bash
sudo scripts/install-freebox-api-lib.sh
```

> The script downloads a third-party Bash file without signature verification. Review the source repository before running it in a sensitive environment.

### Secrets

```bash
mkdir -p /root/.secrets/certbot /root/.secrets/freebox
chmod 700 /root/.secrets/certbot /root/.secrets/freebox

cp config/infomaniak.ini.example /root/.secrets/certbot/infomaniak.ini
chmod 600 /root/.secrets/certbot/infomaniak.ini
vi /root/.secrets/certbot/infomaniak.ini

cp config/freebox-cert.env.example /root/.secrets/freebox/freebox-cert.env
chmod 600 /root/.secrets/freebox/freebox-cert.env
vi /root/.secrets/freebox/freebox-cert.env
```

### Freebox token

```bash
scripts/authorize-freebox-app.sh
```

Validate on the Freebox screen, then paste `MY_APP_TOKEN` into `freebox-cert.env`.

## First certificate

```bash
export INFOMANIAK_API_TOKEN="$(
  awk -F'= *' '/dns_infomaniak_token/ {print $2}' /root/.secrets/certbot/infomaniak.ini
)"

/opt/certbot-infomaniak/bin/certbot certonly \
  --cert-name mysite.example.com \
  --authenticator dns-infomaniak \
  --dns-infomaniak-propagation-seconds 600 \
  --key-type rsa \
  --rsa-key-size 2048 \
  -d mysite.example.com
```

## Deployment

```bash
/usr/local/sbin/deploy-cert-to-freebox
```

Manual external verification:

```bash
echo | openssl s_client \
  -connect "mysite.example.com:1234" \
  -servername "mysite.example.com" \
  2>/dev/null \
| openssl x509 -noout -subject -issuer -dates -serial
```

Deployment logs are written to `/var/log/freebox-cert/`, one timestamped file per run:

```bash
ls -lt /var/log/freebox-cert/
tail -50 /var/log/freebox-cert/deploy-$(ls -t /var/log/freebox-cert/ | head -1)
```

## Multi-host audit

Checks the expiry of every TLS certificate in the perimeter with a single command.

Create the inventory file (optional):

```bash
cp config/cert-audit.hosts.example /root/.secrets/cert-audit.hosts
chmod 600 /root/.secrets/cert-audit.hosts
vi /root/.secrets/cert-audit.hosts
```

Format:

```
mysite.example.com:1234:Freebox OS
mail.example.tld:443:Webmail
```

Run the audit:

```bash
HOSTS_FILE=/root/.secrets/cert-audit.hosts scripts/audit-cert-expiry.sh
```

Example output:

```
HOST                                       PORT   EXPIRES IN   STATUS
────────────────────────────────────────   ────   ──────────   ──────
Freebox OS                                 1234   72d          OK
Webmail                                    443    8d           WARN
```

Return code: `0` OK · `1` WARN (< 30 days) · `2` CRIT (< 14 days) or error.


The thresholds are configurable:

```bash
WARN_DAYS=45 CRIT_DAYS=10 HOSTS_FILE=... scripts/audit-cert-expiry.sh
```

## Automatic renewal

Test:

```bash
/usr/local/sbin/certbot-renew-infomaniak --dry-run
```

Cron:

```cron
17 3 * * * /usr/local/sbin/certbot-renew-infomaniak --quiet
```

## Security

Never commit the real files:

```
/root/.secrets/certbot/infomaniak.ini
/root/.secrets/freebox/freebox-cert.env
```

The `.gitignore` excludes `*.env` and `*.ini`. The `.example` files in the `config/` folder do not match these patterns and are committed normally.

## External dependencies

| Component | Source | License | Role |
|---|---|---|---|
| `fbx-delta-nba_bash_api.sh` | [nbanb/fbx-delta-nba_bash_api.sh](https://github.com/nbanb/fbx-delta-nba_bash_api.sh) | GPLv3 | Bash library for accessing the Freebox OS API |
| `certbot-dns-infomaniak` | [Infomaniak/certbot-dns-infomaniak](https://github.com/Infomaniak/certbot-dns-infomaniak) | Apache-2.0 | Certbot plugin for the DNS-01 challenge via Infomaniak |

`fbx-delta-nba_bash_api.sh` exposes undocumented functions of the Freebox OS API. The `install-freebox-api-lib.sh` script downloads it from the original repository. Verify the file integrity after download if your environment requires it.

## Limitations

- Replacing an existing certificate requires deleting then recreating the Freebox domain, as the API exposes no update endpoint. The script handles this case automatically.
- TLS verification from the LAN often fails because of NAT loopback, so it is better to test from outside.
- RSA only; ECDSA is not yet supported on the Freebox side.
- Secrets are stored under `/root/.secrets/`, which is acceptable on a LAN machine dedicated to this use. On a multi-user infrastructure, prefer a dedicated system user with sudo access limited to the required commands only.

---

## License

MIT - see [LICENSE](LICENSE).

---

*The anonymization of the data shown here, the formatting of the code and text for publication, and the `audit-cert-expiry.sh` script were produced with the assistance of Claude (Anthropic). Everything was reviewed and validated by the author before publication. The actual code, architecture and technical choices are the author's own.*
