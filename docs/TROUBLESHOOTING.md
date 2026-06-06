# Troubleshooting

## Certbot does not offer DNS-01

Check:

```bash
/opt/certbot-infomaniak/bin/certbot plugins
```

The `dns-infomaniak` plugin must appear.

## cannot authenticate

Test the Infomaniak API:

```bash
TOKEN="$(awk -F'= *' '/dns_infomaniak_token/ {print $2}' /root/.secrets/certbot/infomaniak.ini)"

curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" \
  "https://api.infomaniak.com/2/zones/example.tld"
```

If `not_authorized`, the token does not have rights on the zone.

## NXDOMAIN on _acme-challenge

Use:

```bash
/opt/certbot-infomaniak/bin/certbot certonly \
  --dry-run \
  --debug-challenges \
  --cert-name mysite.example.com \
  --authenticator dns-infomaniak \
  --dns-infomaniak-propagation-seconds 600 \
  -d mysite.example.com
```

During the pause:

```bash
dig TXT _acme-challenge.mysite.example.com @nsany1.infomaniak.com
dig TXT _acme-challenge.mysite.example.com @nsany2.infomaniak.com
dig TXT _acme-challenge.mysite.example.com
```

## Freebox API invalid_token

Re-authorize the Freebox application and update:

```text
/root/.secrets/freebox/freebox-cert.env
```

## domain_list command not found

You must source the library:

```bash
source /opt/freebox-api/fbx-delta-nba_bash_api.sh
```

## Script stuck on detect_term_bg_color

The Freebox library uses uninitialized variables and returns non-zero
on load. The `deploy-cert-to-freebox` script disables `set -e` around the
`source` and does not use `set -u` for this reason.

## openssl from the LAN returns connection refused

The Freebox OS external port may not be reachable from the LAN because of NAT loopback.
Test from an external machine.

## domain_addcert returns an "exists" error

The Freebox API exposes `domain/owned/{id}/import_cert/` as POST only; there is no update endpoint. Trying to import an RSA certificate on a domain that already has one returns an "exists" error.

The `deploy-cert-to-freebox` script handles this case by deleting then recreating the domain before each import:

```bash
domain_del id="mysite.example.com"
domain_add id="mysite.example.com"
domain_addcert id="mysite.example.com" key_type="rsa" ...
```

If the error persists in manual mode, check that `domain_del` returned 0 before running `domain_add` again.

## Wrong certificate still showing

Check:

```bash
domain_list
```

The `rsa` field shows the number of remaining validity days of the imported certificate. The line should look like:

```text
owner: user   type: custom   rsa: <days>   id default: mysite.example.com
```

If the external certificate remains `*.fbxos.fr`, check that the custom domain is set as the default domain in Freebox OS.
