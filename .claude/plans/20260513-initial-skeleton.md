# x100-rack — Initial Skeleton Plan

## Context

x100-rack is a mountable Rack web app providing a UI for the BSV wallet. It sits alongside x402-rack in a composable "rack stack" — middleware handles payments (x402) and auth (x403), the mountable app provides the dashboard. Named for BRC-100 and HTTP 100 Continue ("your app continues, the stack handles the money").

The repo exists at `/opt/ruby/x100-rack` (GitHub: sgbett/x100-rack) with just a README and .gitignore. This plan builds the initial skeleton: gem structure, routes, templates, session/auth framework, and engine integration pattern.

## Technology Choices

- **Roda** — tree routing is explicit and composable, `plugin` system covers render/sessions/static, apps are plain Rack. Better fit than Sinatra for a mountable component.
- **htmx** — dynamic behavior without JS build tooling. CDN link in layout.
- **Pico CSS** — classless/minimal CSS framework. CDN link. No custom CSS needed for skeleton.
- **ERB via Erubi** — auto-escaped templates, Roda's render plugin default.
- **AES-256-GCM** — WIF encryption at rest. PBKDF2 key derivation from password. Ruby stdlib `openssl`, no extra gems.

## Route Structure

All routes under `/x100` (configured by the consumer's `map` or `mount`):

```
GET  /              → Home (locked: unlock/setup, unlocked: balance + send)
GET  /legacy        → Legacy payment (requires unlock)
GET  /actions       → Transaction list (requires unlock)
GET  /settings      → Settings (requires unlock)
POST /unlock        → Decrypt WIF, boot engine, redirect to /
POST /setup         → First-run: encrypt WIF, persist, redirect to /
POST /lock          → Clear session + engine, redirect to /
POST /send          → Send payment (future, not in skeleton)
```

## File Structure

```
x100-rack/
├── lib/
│   ├── x100.rb                     # Entry point
│   └── x100/
│       ├── version.rb
│       ├── web.rb                  # Roda app — routes + plugins
│       ├── auth.rb                 # Session timeout + locked/unlocked helpers
│       └── wallet_manager.rb       # Engine lifecycle: setup/unlock/lock, WIF encryption
├── views/
│   ├── layout.erb                  # Nav bar, Pico CSS, htmx
│   ├── home.erb                    # Balance + send (unlocked) or unlock/setup (locked)
│   ├── legacy.erb                  # Legacy address send/receive
│   ├── actions.erb                 # Transaction table
│   ├── settings.erb                # Session timeout config
│   ├── _unlock.erb                 # Password form partial
│   └── _setup.erb                  # First-run: show WIF, set password
├── spec/
│   ├── spec_helper.rb
│   └── x100/
│       ├── web_spec.rb
│       └── wallet_manager_spec.rb
├── x100-rack.gemspec
├── Gemfile
├── Rakefile
├── config.ru                       # Dev server for manual testing
├── CLAUDE.md
├── .rspec
├── .rubocop.yml
├── .gitignore                      # (exists)
└── README.md                       # (exists, update mounting examples)
```

## Key Design Decisions

### Engine Lifecycle (WalletManager)

The wallet engine is expensive (DB connection, key derivation). Lives at the app level, not per-request.

```ruby
wallet_mgr = X100::WalletManager.new(storage_path: "~/.x100")

# Consumer mounts:
map "/x100" { run X100::Web.create(wallet_manager: wallet_mgr) }
```

WalletManager states:
1. **First run** (`first_run?` = true) — no encrypted WIF file exists
2. **Locked** — encrypted WIF exists, engine not constructed
3. **Unlocked** — engine alive, WIF decrypted in memory

`setup!` generates a new private key (via SDK), encrypts WIF with password, writes `wallet.enc`. `unlock!` decrypts WIF, calls `CLI.boot`-like construction. `lock!` nils out the engine.

Encrypted file format: JSON with `salt` (hex), `iv` (hex), `ciphertext` (hex), `auth_tag` (hex). PBKDF2 (100k iterations, SHA256) derives the AES key from password + salt.

### Session Management

Roda `sessions` plugin (encrypted cookie). Session stores `unlocked_at` timestamp. On each request, if `unlocked_at` is older than timeout (default 15 min), auto-lock. Activity resets the timer.

The session does NOT store the WIF — that lives only in WalletManager's memory. Session just tracks "this browser is authenticated."

### Mounting API

```ruby
# Roda class-level configuration via factory
app = X100::Web.create(wallet_manager: wallet_mgr)

# Raw Rack
map "/x100" { run app }

# Rails
mount app => "/x100"
```

`create` returns a Roda subclass with `opts[:wallet_manager]` set. This is standard Roda parameterization — each mount gets its own config without class-level mutation.

### Nav Bar Behavior

- **Locked**: Home link active, Legacy/Transactions/Settings grayed out (disabled)
- **Unlocked**: All links active
- Lock button visible when unlocked

### Dependencies

**Runtime:**
- `roda` (~> 3.0)
- `tilt` (~> 2.0)
- `erubi` (~> 1.0)
- `bsv-wallet` (>= 0.9.1, < 1.0)
- `rack` (~> 3.0)

**Dev:**
- `rspec`, `rack-test`, `rubocop`, `rackup`

No `bsv-wallet-postgres` dependency — that's the consumer's choice. WalletManager requires `DATABASE_URL` env var at unlock time (same as CLI.boot).

## Implementation Sequence

### Step 1: Gem scaffolding
- gemspec, Gemfile, Rakefile, .rspec, .rubocop.yml, CLAUDE.md
- `lib/x100.rb`, `lib/x100/version.rb`
- `spec/spec_helper.rb`
- Verify `bundle install` passes

### Step 2: Roda app + static templates
- `lib/x100/web.rb` — Roda app with render plugin, all 4 GET routes
- `views/layout.erb` — nav, Pico CSS, htmx CDN
- `views/home.erb`, `views/legacy.erb`, `views/actions.erb`, `views/settings.erb` — placeholder content
- `config.ru` — dev server
- `spec/x100/web_spec.rb` — route smoke tests

### Step 3: Auth framework
- `lib/x100/auth.rb` — session helpers (check_timeout!, require_unlocked!, unlocked?)
- Add `sessions` plugin to web.rb
- Lock gates on legacy/actions/settings routes
- `views/_unlock.erb`, `views/_setup.erb` partials
- Update home.erb for locked/unlocked states
- Update layout.erb nav for locked state

### Step 4: WalletManager
- `lib/x100/wallet_manager.rb` — first_run?, setup!, unlock!, lock!, engine, balance, identity_key
- AES-256-GCM encryption/decryption of WIF
- Wire POST routes: /unlock, /setup, /lock
- `spec/x100/wallet_manager_spec.rb`

### Step 5: Engine integration
- Wire real engine methods into templates (balance, identity_key, list_actions)
- Update README with final mounting examples
- `config.ru` working end-to-end with bsv-wallet-postgres

## Verification

1. `bundle exec rspec` — all specs green
2. `bundle exec rubocop` — no offenses
3. Manual: `rackup config.ru`, visit `http://localhost:9292/x100`
   - See setup form on first run
   - Set password, see balance + nav unlock
   - Navigate all pages
   - Wait 15 min (or set timeout to 10s for testing) — auto-locks
4. Mount alongside x402-rack in a test config.ru — both coexist at different paths

## Reference Files
- `/opt/ruby/x402-rack/x402-rack.gemspec` — gemspec template
- `/opt/ruby/x402-rack/lib/x402/status_endpoint.rb` — mountable Rack endpoint pattern
- `/opt/ruby/bsv-wallet/gem/bsv-wallet/lib/bsv/wallet/cli.rb` — CLI.boot pattern for engine construction
- `/opt/ruby/bsv-wallet/gem/bsv-wallet/lib/bsv/wallet/engine.rb` — engine public API
