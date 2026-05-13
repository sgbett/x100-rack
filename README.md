# x100-rack

Composable Rack wallet UI for BSV. Named for BRC-100 (the wallet specification) and HTTP 100 Continue — your app continues doing what it does, the x1xx stack handles the money.

## What It Does

x100-rack is a mountable Rack application that provides a web UI for BSV wallet operations. Mount it at `/x100` (or any path) in any Rack-compatible app — Rails, Sinatra, Roda, or raw Rack.

- **Home** — balance display, send payments
- **Legacy Payment** — address-based send/receive
- **Transactions** — action history with inputs/outputs
- **Settings** — session timeout configuration

The wallet starts locked. On first run, a new private key is generated and encrypted with a password. On subsequent runs, enter the password to unlock. Sessions auto-lock after 15 minutes of inactivity.

## Quick Start

```ruby
# config.ru
require "x100"

wallet_mgr = X100::WalletManager.new(storage_path: "~/.x100")
app = X100::Web.create(wallet_manager: wallet_mgr)

map "/x100" { run app }
```

```bash
# Requires DATABASE_URL for full wallet engine (after unlock)
export DATABASE_URL="postgres://localhost/my_wallet"
export X100_SESSION_SECRET="$(ruby -e 'require "securerandom"; puts SecureRandom.hex(32)')"
rackup
```

Visit `http://localhost:9292/x100`.

## The x1xx Rack Stack

x100-rack is designed to compose with other x1xx middleware components:

```ruby
# Full stack: payments + auth + wallet UI
require "x100"
require "x402"

wallet_mgr = X100::WalletManager.new(storage_path: "~/.x100")

# Middleware — transparent, intercepts HTTP responses
use X402::Middleware

# Mountable app — wallet dashboard at /x100
map "/x100" { run X100::Web.create(wallet_manager: wallet_mgr) }

# Your app — untouched
map "/" { run MyApp }
```

| Component | Type | Description |
|-----------|------|-------------|
| **x100** | Mountable app | Wallet dashboard UI |
| **x402** | Middleware | BSV payment negotiation (HTTP 402) |
| **x403** | Middleware | Certificate-based identity (HTTP 403) |

### Rails

```ruby
# config/routes.rb
wallet_mgr = X100::WalletManager.new(storage_path: "~/.x100")
mount X100::Web.create(wallet_manager: wallet_mgr) => "/x100"
```

## Architecture

Built on [bsv-wallet](https://github.com/sgbett/bsv-wallet), a Ruby implementation of the BRC-100 wallet specification.

- **Roda** — tree routing, explicit and composable
- **htmx** — dynamic behavior without JavaScript build tooling
- **Pico CSS** — minimal classless styling
- **AES-256-GCM** — private key encrypted at rest (PBKDF2 key derivation)

The `WalletManager` handles the wallet lifecycle (setup, unlock, lock). The wallet engine is constructed lazily on first access after unlock, requiring `DATABASE_URL` and `bsv-wallet-postgres`.

## Dependencies

- `roda` (~> 3.0)
- `bsv-wallet` (>= 0.9.1, < 1.0)
- `rack` (~> 3.0)

`bsv-wallet-postgres` is required at runtime (for the database-backed engine) but is not a gem dependency — the consumer provides it.

## License

MIT
