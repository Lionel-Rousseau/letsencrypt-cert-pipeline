# letsencrypt-cert-pipeline

Renouvellement automatique d'un certificat Let's Encrypt et déploiement vers Freebox OS, sans intervention manuelle.

```
Certbot (DNS-01 via Infomaniak)
→ certificat RSA Let's Encrypt
→ import dans Freebox OS (fbx-delta-nba_bash_api.sh)
→ vérification TLS depuis l'extérieur
```

> ⚠️ L'import certificat Freebox repose sur des endpoints non documentés de l'API. Une mise à jour Freebox OS peut casser ce workflow.

## Contexte testé

| Élément | Valeur |
|---|---|
| DNS | Infomaniak |
| Challenge ACME | DNS-01 |
| Certbot | venv Python isolé |
| Certificat | RSA 2048 bits |
| API Freebox | fbx-delta-nba_bash_api.sh |
| Machine | Raspberry Pi / Debian LAN |

## Structure

```
letsencrypt-cert-pipeline/
├── config/
│   ├── freebox-cert.env.example
│   ├── infomaniak.ini.example
│   └── cert-audit.hosts.example
├── scripts/
│   ├── install-prereqs.sh
│   ├── install-freebox-api-lib.sh
│   ├── authorize-freebox-app.sh
│   ├── certbot-renew-infomaniak
│   ├── deploy-cert-to-freebox
│   ├── check-freebox-cert
│   └── audit-cert-expiry.sh
└── docs/
    ├── OPERATING_PROCEDURE.md
    └── TROUBLESHOOTING.md
```

## Installation

### Dépendances système

```bash
sudo scripts/install-prereqs.sh
```

### Librairie Freebox API

```bash
sudo scripts/install-freebox-api-lib.sh
```

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

### Token Freebox

```bash
scripts/authorize-freebox-app.sh
```

Valider sur l'écran de la Freebox, puis coller `MY_APP_TOKEN` dans `freebox-cert.env`.

## Premier certificat

```bash
export INFOMANIAK_API_TOKEN="$(
  awk -F'= *' '/dns_infomaniak_token/ {print $2}' /root/.secrets/certbot/infomaniak.ini
)"

/opt/certbot-infomaniak/bin/certbot certonly \
  --cert-name home.example.tld \
  --authenticator dns-infomaniak \
  --dns-infomaniak-propagation-seconds 600 \
  --key-type rsa \
  --rsa-key-size 2048 \
  -d home.example.tld
```

## Déploiement

```bash
/usr/local/sbin/deploy-cert-to-freebox
```

Vérification externe :

```bash
echo | openssl s_client \
  -connect "home.example.tld:1688" \
  -servername "home.example.tld" \
  2>/dev/null \
| openssl x509 -noout -subject -issuer -dates -serial
```

## Audit multi-hôtes

Vérifie l'expiration de tous les certificats TLS du périmètre en une commande.

Créer le fichier d'inventaire :

```bash
cp config/cert-audit.hosts.example /root/.secrets/cert-audit.hosts
chmod 600 /root/.secrets/cert-audit.hosts
vi /root/.secrets/cert-audit.hosts
```

Format :

```
home.example.tld:1688:Freebox OS
mail.example.tld:443:Webmail
```

Lancer l'audit :

```bash
HOSTS_FILE=/root/.secrets/cert-audit.hosts scripts/audit-cert-expiry.sh
```

Exemple de sortie :

```
HOST                                       PORT   EXPIRES IN   STATUS
────────────────────────────────────────   ────   ──────────   ──────
Freebox OS                                 1688   72d          OK
Webmail                                    443    8d           WARN
```

Code de retour : `0` OK · `1` WARN (< 30 jours) · `2` CRIT (< 14 jours) ou erreur.

Intégration cron :

```cron
0 8 * * 1 HOSTS_FILE=/root/.secrets/cert-audit.hosts /usr/local/sbin/audit-cert-expiry.sh
```

Les seuils sont configurables :

```bash
WARN_DAYS=45 CRIT_DAYS=10 HOSTS_FILE=... scripts/audit-cert-expiry.sh
```

## Renouvellement automatique

Test :

```bash
/usr/local/sbin/certbot-renew-infomaniak --dry-run
```

Cron :

```cron
17 3 * * * /usr/local/sbin/certbot-renew-infomaniak --quiet
```

## Sécurité

Ne jamais versionner les fichiers réels :

```
/root/.secrets/certbot/infomaniak.ini
/root/.secrets/freebox/freebox-cert.env
```

Le `.gitignore` exclut `*.env` et `*.ini`. Les fichiers `.example` du dossier `config/` ne correspondent pas à ces patterns et sont versionnés normalement.

## Limites

- Le script ne supprime pas le domaine custom existant avant l'import (comportement volontairement non-destructif).
- La vérification TLS depuis le LAN échoue souvent à cause du NAT loopback — tester depuis l'extérieur.
- RSA uniquement, ECDSA non supporté côté Freebox pour l'instant.
