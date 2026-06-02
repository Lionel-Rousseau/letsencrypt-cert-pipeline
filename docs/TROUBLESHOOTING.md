# Troubleshooting

## Certbot ne propose pas DNS-01

Vérifier :

```bash
/opt/certbot-infomaniak/bin/certbot plugins
```

Le plugin `dns-infomaniak` doit apparaître.

## cannot authenticate

Tester l’API Infomaniak :

```bash
TOKEN="$(awk -F'= *' '/dns_infomaniak_token/ {print $2}' /root/.secrets/certbot/infomaniak.ini)"

curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "https://api.infomaniak.com/2/zones/example.tld"
```

Si `not_authorized`, le token n’a pas les droits sur la zone.

## NXDOMAIN sur _acme-challenge

Utiliser :

```bash
/opt/certbot-infomaniak/bin/certbot certonly \
  --dry-run \
  --debug-challenges \
  --cert-name mysite.example.com \
  --authenticator dns-infomaniak \
  --dns-infomaniak-propagation-seconds 600 \
  -d mysite.example.com
```

Pendant la pause :

```bash
dig TXT _acme-challenge.mysite.example.com @nsany1.infomaniak.com
dig TXT _acme-challenge.mysite.example.com @nsany2.infomaniak.com
dig TXT _acme-challenge.mysite.example.com
```

## Freebox API invalid_token

Réautoriser l’application Freebox et mettre à jour :

```text
/root/.secrets/freebox/freebox-cert.env
```

## domain_list command not found

Il faut sourcer la librairie :

```bash
source /opt/freebox-api/fbx-delta-nba_bash_api.sh
```

## Script bloqué sur detect_term_bg_color

La librairie Freebox peut retourner non-zéro au chargement à cause de `read -t`.
Le script `deploy-cert-to-freebox` désactive temporairement `set -e` autour du `source`.

## openssl depuis le LAN retourne connection refused

Le port externe Freebox OS peut ne pas être joignable depuis le LAN à cause du NAT loopback.
Tester depuis une machine externe.

## domain_addcert retourne une erreur "exists"

L'API Freebox expose `domain/owned/{id}/import_cert/` en POST uniquement — il n'existe pas d'endpoint de mise à jour. Tenter d'importer un certificat RSA sur un domaine qui en a déjà un retourne une erreur "exists".

Le script `deploy-cert-to-freebox` gère ce cas en supprimant puis recréant le domaine avant chaque import :

```bash
domain_del id="mysite.example.com"
domain_add id="mysite.example.com"
domain_addcert id="mysite.example.com" key_type="rsa" ...
```

Si l'erreur persiste en mode manuel, vérifier que `domain_del` a bien retourné 0 avant de relancer `domain_add`.

## Mauvais certificat encore visible

Vérifier :

```bash
domain_list
```

Le champ `rsa` indique le nombre de jours de validité restants du certificat importé. La ligne doit ressembler à :

```text
owner: user   type: custom   rsa: <jours>   id default: mysite.example.com
```

Si le certificat externe reste `*.fbxos.fr`, vérifier que le domaine custom est bien défini comme domaine par défaut dans Freebox OS.
