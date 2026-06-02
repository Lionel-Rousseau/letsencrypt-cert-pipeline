# Mode opératoire

## 1. Préparer la machine interne

```bash
apt update
apt install -y curl openssl jq coreutils file python3-venv python3-pip dnsutils
```

## 2. Installer Certbot dans un venv

```bash
python3 -m venv /opt/certbot-infomaniak
/opt/certbot-infomaniak/bin/pip install --upgrade pip
/opt/certbot-infomaniak/bin/pip install certbot certbot-dns-infomaniak
```

## 3. Installer la librairie Freebox API

```bash
scripts/install-freebox-api-lib.sh
```

## 4. Créer les secrets

```bash
mkdir -p /root/.secrets/certbot /root/.secrets/freebox
chmod 700 /root/.secrets/certbot /root/.secrets/freebox

cp config/infomaniak.ini.example /root/.secrets/certbot/infomaniak.ini
cp config/freebox-cert.env.example /root/.secrets/freebox/freebox-cert.env

chmod 600 /root/.secrets/certbot/infomaniak.ini
chmod 600 /root/.secrets/freebox/freebox-cert.env
```

Éditer les deux fichiers.

## 5. Tester Infomaniak

```bash
TOKEN="$(awk -F'= *' '/dns_infomaniak_token/ {print $2}' /root/.secrets/certbot/infomaniak.ini)"

curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "https://api.infomaniak.com/2/zones/example.tld"
```

## 6. Autoriser l’application Freebox

```bash
scripts/authorize-freebox-app.sh fr.example.freebox.certdeploy "Freebox Cert Deploy" "1.0.0" "linux-host"
```

Valider côté Freebox.

## 7. Tester le login Freebox

```bash
debug=0
pretty=1
source /opt/freebox-api/fbx-delta-nba_bash_api.sh
source /root/.secrets/freebox/freebox-cert.env

login_freebox "$FREEBOX_APP_ID" "$FREEBOX_APP_TOKEN" --access
domain_list
```

## 8. Émettre le certificat

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

## 9. Déployer dans la Freebox

```bash
/usr/local/sbin/deploy-cert-to-freebox
```

## 10. Tester depuis l’extérieur

```bash
echo | openssl s_client \
  -connect "home.example.tld:1688" \
  -servername "home.example.tld" \
  2>/dev/null \
| openssl x509 -noout -subject -issuer -dates -serial
```

## 11. Activer le renouvellement

```bash
/usr/local/sbin/certbot-renew-infomaniak --dry-run
```

Puis cron :

```cron
17 3 * * * /usr/local/sbin/certbot-renew-infomaniak --quiet
```
