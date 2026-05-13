# x100-rack

Composable Rack middleware stack for BSV wallet operations. Named for BRC-100 (the wallet specification) and HTTP 100 Continue — your app continues doing what it does, the x1xx stack handles the money.

## Architecture

The stack is built on [bsv-wallet](https://github.com/sgbett/bsv-wallet), a Ruby implementation of the BRC-100 wallet specification. Components compose at the Rack layer:

- **Middleware** intercepts HTTP responses (402 Payment Required, 403 Forbidden) and handles BSV protocol negotiation transparently
- **Mountable apps** provide optional UI endpoints (wallet dashboard, transaction history) that slot into any Rack-compatible application

A single `BSV::Wallet::Engine` instance is shared across all components — payments negotiated by middleware appear instantly in the dashboard.

## Planned Components

| Component | Type | Description |
|-----------|------|-------------|
| `x402` | Middleware | BSV payment negotiation for HTTP 402 responses |
| `x403` | Middleware | Certificate-based identity/authentication |
| `x100-wallet-web` | Mountable app | Wallet dashboard UI |

## Usage

```ruby
# In any Rack application (Rails, Sinatra, Roda, raw Rack)
engine = BSV::Wallet::Engine.new(store:, utxo_pool:, ...)

use X402::Payment, wallet: engine
use X403::Identity, wallet: engine

map '/wallet' { run X100::Wallet::Web.new(engine:) }
```

Rails apps can mount individual components without adopting the full stack.

## License

MIT
