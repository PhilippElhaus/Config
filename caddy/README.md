# imac.lan web ingress

The existing Windows Caddy service owns ports 80 and 443. Its executable is
`C:\Caddy\caddy.exe` and its live configuration is `C:\Caddy\Caddyfile`.
`imac.Caddyfile` is the reviewed source for that configuration.

| URL | Application |
| --- | --- |
| `https://wtf.imac.lan` | The existing static `D:\WTF\Dev` workspace |
| `http://localhost` and `http://127.0.0.1` | The existing WTF development root |

The user authorized private LAN access without a separate login. HTTPS routes
reject clients outside private address ranges. Cezar was retired on October 4.
The Caddy admin API remains loopback-only.

Gateway owns the WTF DNS record at `10.0.0.30`. Server owns the Step CA at
`https://ca.lan:8443/acme/acme/directory`. The public root certificate is copied
from the existing `Z:\Certs\Elhaus-LAN-RootCA.cer` into
`C:\Caddy\pki\Elhaus-LAN-RootCA.crt` after fingerprint verification. Private
keys and ACME state stay in the Caddy service's normal data directory. Never
copy CA private keys into this configuration or Git.

## Apply and recover

Verify the source diff. Run `caddy validate` with the installed public root.
Back up the exact live Caddyfile before replacement. Copy this source to the
live path, then use `caddy reload --config C:\Caddy\Caddyfile --adapter caddyfile`.
Preserve the existing Windows service and its storage. Allow inbound TCP 80
and 443 only from private LAN clients when a firewall rule is needed.

Check DNS, HTTP redirects, WTF HTTPS with normal certificate validation,
and the original localhost route. Server and Gateway must be available for
certificate issuance and renewal. The existing Caddy service starts with Windows.

For rollback, restore the exact retained Caddyfile and reload it. Remove only
the firewall rule created for this change if present. Preserve all Caddy data.
