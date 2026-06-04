# Let's Encrypt TLS Pipeline : Certbot DNS-01 → Freebox OS

Renouvellement automatique d'un certificat Let's Encrypt et déploiement vers Freebox OS, sans intervention manuelle.
Code issu d'un cas réel d'exploitation, anonymisé et adapté pour publication.

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
│   ├── install-prereqs.sh         # setup ponctuel
│   ├── install-freebox-api-lib.sh # setup ponctuel
│   ├── authorize-freebox-app.sh   # setup ponctuel
│   ├── certbot-renew-infomaniak   # installé dans sbin/, appelé par cron
│   ├── deploy-cert-to-freebox     # installé dans sbin/, appelé par cron
│   ├── check-freebox-cert         # installé dans sbin/, appelé par cron
│   └── audit-cert-expiry.sh       # audit à la demande
└── docs/
    ├── OPERATING_PROCEDURE.md
    └── TROUBLESHOOTING.md
```

Les scripts destinés à être installés dans `/usr/local/sbin/` et appelés en tant que commandes système n'ont pas d'extension (convention Unix). Les scripts à usage ponctuel conservent `.sh`.

## Installation

### Dépendances système

```bash
sudo scripts/install-prereqs.sh
```

### Librairie Freebox API

Télécharge [fbx-delta-nba_bash_api.sh](https://github.com/nbanb/fbx-delta-nba_bash_api.sh) depuis le dépôt d'origine et l'installe dans `/opt/freebox-api/`.

```bash
sudo scripts/install-freebox-api-lib.sh
```

> Le script télécharge un fichier Bash tiers sans vérification de signature. Consulter le dépôt source avant exécution dans un environnement sensible.

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
  --cert-name mysite.example.com \
  --authenticator dns-infomaniak \
  --dns-infomaniak-propagation-seconds 600 \
  --key-type rsa \
  --rsa-key-size 2048 \
  -d mysite.example.com
```

## Déploiement

```bash
/usr/local/sbin/deploy-cert-to-freebox
```

Vérification externe manuelle :

```bash
echo | openssl s_client \
  -connect "mysite.example.com:1234" \
  -servername "mysite.example.com" \
  2>/dev/null \
| openssl x509 -noout -subject -issuer -dates -serial
```

Les logs de déploiement sont écrits dans `/var/log/freebox-cert/` — un fichier par exécution, horodaté :

```bash
ls -lt /var/log/freebox-cert/
tail -50 /var/log/freebox-cert/deploy-$(ls -t /var/log/freebox-cert/ | head -1)
```

## Audit multi-hôtes

Vérifie l'expiration de tous les certificats TLS du périmètre en une commande.

Créer le fichier d'inventaire (optionnel) :

```bash
cp config/cert-audit.hosts.example /root/.secrets/cert-audit.hosts
chmod 600 /root/.secrets/cert-audit.hosts
vi /root/.secrets/cert-audit.hosts
```

Format :

```
mysite.example.com:1234:Freebox OS
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
Freebox OS                                 1234   72d          OK
Webmail                                    443    8d           WARN
```

Code de retour : `0` OK · `1` WARN (< 30 jours) · `2` CRIT (< 14 jours) ou erreur.


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

Le `.gitignore` exclut `*.env` et `*.ini`. Les fichiers `.example` du dossier `config/` ne correspondent pas à ces fichiers et sont versionnés normalement.

## Dépendances externes

| Composant | Source | Licence | Rôle |
|---|---|---|---|
| `fbx-delta-nba_bash_api.sh` | [nbanb/fbx-delta-nba_bash_api.sh](https://github.com/nbanb/fbx-delta-nba_bash_api.sh) | GPLv3 | Bibliothèque Bash d'accès à l'API Freebox OS |
| `certbot-dns-infomaniak` | [Infomaniak/certbot-dns-infomaniak](https://github.com/Infomaniak/certbot-dns-infomaniak) | Apache-2.0 | Plugin Certbot pour le challenge DNS-01 via Infomaniak |

`fbx-delta-nba_bash_api.sh` expose des fonctions non documentées de l'API Freebox OS. Le script `install-freebox-api-lib.sh` la télécharge depuis le dépôt d'origine. Vérifier l'intégrité du fichier après téléchargement si l'environnement l'exige.

## Limites

- Le remplacement d'un certificat existant nécessite de supprimer puis recréer le domaine Freebox — l'API n'expose pas d'endpoint de mise à jour. Le script gère ce cas automatiquement.
- La vérification TLS depuis le LAN échoue souvent à cause du NAT loopback, il est préferrable de tester depuis l'extérieur.
- RSA uniquement, ECDSA non supporté côté Freebox pour l'instant.
- Les secrets sont stockés sous `/root/.secrets/` ce qui est acceptable à une machine LAN dédiée à cet usage. Sur une infrastructure multi-utilisateurs, préférer un utilisateur système dédié avec accès sudo limité aux seules commandes nécessaires.

---

## Licence

MIT — voir [LICENSE](LICENSE).

---

*L'anonymisation des données présentées, la mise en forme du code et des textes en vue de leur publication ainsi que le script `audit-cert-expiry.sh` ont été réalisées avec l'assistance de Claude (Anthropic). L'ensemble a été relu et validé par l'auteur avant publication. Le code réel, l'architecture et les choix techniques sont de l'auteur.*
