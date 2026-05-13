# x100-rack — Project Instructions

## Overview

Mountable Rack web app providing a wallet UI for BSV (BRC-100). Part of the x1xx composable rack stack alongside x402-rack (payment middleware).

## Language Convention: American English

Matches bsv-wallet convention. Examples: behavior, color, organization, optimize.

## Running Specs

```bash
bundle exec rspec
bundle exec rubocop
```

## Architecture

- **Framework**: Roda (tree routing, plugin system)
- **Templates**: ERB via Erubi (auto-escaped), file-based in `views/`
- **CSS**: Pico CSS (CDN, classless)
- **JS**: htmx (CDN, no build tooling)
- **Session**: Roda sessions plugin (encrypted cookie)
- **WIF storage**: AES-256-GCM encrypted file, PBKDF2 key derivation

## Mounting

```ruby
wallet_mgr = X100::WalletManager.new(storage_path: "~/.x100")
app = X100::Web.create(wallet_manager: wallet_mgr)
map "/x100" { run app }
```

## Key Classes

- `X100::Web` — Roda app, routes and rendering
- `X100::WalletManager` — Engine lifecycle (setup/unlock/lock), WIF encryption
- `X100::Auth` — Session timeout and locked/unlocked helpers
