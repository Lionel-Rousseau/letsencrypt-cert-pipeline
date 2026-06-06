# Operating procedure

## 1. Prepare the internal machine

```bash
apt update
apt install -y curl openssl jq coreutils file python3-venv python3-pip dnsutils
```

## 2. Install Certbot in a venv

```bash
python3 -m venv /opt/certbot-infomaniak
/opt/certbot-infomaniak/bin/pip install --upgrade pip
/opt/certbot-infomaniak/bin/pip install certbot certbot-dns-infomaniak
```

## 3. Install the Freebox API library

```bash
scripts/install-freebox-api-lib.sh
```

## 4. Create the secrets

```bash
mkdir -p /root/.secrets/certbot /root/.secrets/freebox
chmod 700 /root/.secrets/certbot /root/.secrets/freebox

cp config/infomaniak.ini.example /root/.secrets/certbot/infomaniak.ini
cp config/freebox-cert.env.example /root/.secrets/freebox/freebox-cert.env

chmod 600 /root/.secrets/certbot/infomaniak.ini
chmod 600 /root/.secrets/freebox/freebox-cert.env
```

Edit both files.

## 5. Test Infomaniak

```bash
TOKEN="$(awk -F'= *' '/dns_infomaniak_token/ {print $2}' /root/.secrets/certbot/infomaniak.ini)"

curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "https://api.infomaniak.com/2/zones/example.tld"
```

## 6. Authorize the Freebox application

```bash
scripts/authorize-freebox-app.sh fr.example.freebox.certdeploy "Freebox Cert Deploy" "1.0.0" "linux-host"
```

Validate on the Freebox side.

## 7. Test the Freebox login

```bash
debug=0
pretty=1
source /opt/freebox-api/fbx-delta-nba_bash_api.sh
source /root/.secrets/freebox/freebox-cert.env

login_freebox "$FREEBOX_APP_ID" "$FREEBOX_APP_TOKEN" --access
domain_list
```

## 8. Issue the certificate

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

## 9. Deploy to the Freebox

```bash
/usr/local/sbin/deploy-cert-to-freebox
```

## 10. Test from outside

```bash
echo | openssl s_client \
  -connect "mysite.example.com:1234" \
  -servername "mysite.example.com" \
  2>/dev/null \
| openssl x509 -noout -subject -issuer -dates -serial
```

## 11. Enable renewal

```bash
/usr/local/sbin/certbot-renew-infomaniak --dry-run
```

Then cron:

```cron
17 3 * * * /usr/local/sbin/certbot-renew-infomaniak --quiet
```
