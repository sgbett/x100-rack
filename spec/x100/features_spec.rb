# frozen_string_literal: true

RSpec.describe "Feature paths", type: :feature do
  include Rack::Test::Methods

  let(:storage_dir) { Dir.mktmpdir("x100-test") }
  let(:wallet_manager) { X100::WalletManager.new(storage_path: storage_dir) }
  let(:app) { X100::Web.create(wallet_manager: wallet_manager) }

  after { FileUtils.rm_rf(storage_dir) }

  # Helper: create wallet through the app (not direct wallet_manager call)
  def create_wallet!(password: "testpass123")
    post "/setup", password: password, password_confirm: password
    follow_redirect!
  end

  # Helper: lock then unlock through the app
  def lock_and_unlock!(password: "testpass123")
    post "/lock"
    follow_redirect!
    post "/unlock", password: password
    follow_redirect!
  end

  describe "first run → setup → home" do
    it "creates a wallet and shows the recovery key" do
      # 1. Visit home — see setup form
      get "/"
      expect(last_response).to be_ok
      expect(last_response.body).to include("Create Wallet")

      # 2. Submit setup with matching passwords
      create_wallet!

      # 3. Home shows recovery key (WIF)
      expect(last_response).to be_ok
      expect(last_response.body).to include("Save Your Recovery Key")
      expect(last_response.body).to match(/[KL][a-km-zA-HJ-NP-Z1-9]{51}/) # WIF pattern

      # 4. Wallet is unlocked — balance visible
      expect(last_response.body).to include("Balance")

      # 5. WIF is only shown once
      get "/"
      expect(last_response.body).not_to include("Save Your Recovery Key")
      expect(last_response.body).to include("Balance")
    end

    it "rejects mismatched passwords" do
      post "/setup", password: "abc", password_confirm: "xyz"
      follow_redirect!
      expect(last_response.body).to include("Passwords do not match")
      expect(wallet_manager).to be_first_run
    end
  end

  describe "lock → unlock → home" do
    it "locks and unlocks the wallet" do
      create_wallet!

      # Unlocked — home shows balance
      expect(last_response.body).to include("Balance")

      # Lock the wallet
      post "/lock"
      follow_redirect!
      expect(last_response.body).to include("Unlock Wallet")
      expect(last_response.body).not_to include("Balance")

      # Unlock with correct password
      post "/unlock", password: "testpass123"
      follow_redirect!
      expect(last_response.body).to include("Balance")
    end

    it "rejects wrong password" do
      create_wallet!
      post "/lock"
      follow_redirect!

      post "/unlock", password: "wrong"
      follow_redirect!
      expect(last_response.body).to include("Invalid password")
      expect(last_response.body).to include("Unlock Wallet")
    end
  end

  describe "auth gates" do
    it "redirects locked users away from protected pages" do
      %w[/legacy /actions /settings].each do |path|
        get path
        expect(last_response).to be_redirect, "Expected #{path} to redirect when locked"
      end
    end

    it "allows unlocked users to access all pages" do
      create_wallet!

      get "/legacy"
      expect(last_response).to be_ok
      expect(last_response.body).to include("Legacy Payment")

      get "/actions"
      expect(last_response).to be_ok
      expect(last_response.body).to include("Transactions")

      get "/settings"
      expect(last_response).to be_ok
      expect(last_response.body).to include("Settings")
    end
  end

  describe "page content" do
    before { create_wallet! }

    it "home shows labeled identity key and balance" do
      get "/"
      expect(last_response.body).to include("Identity Key")
      expect(last_response.body).to include(wallet_manager.identity_key)
      expect(last_response.body).to include("Balance")
    end

    it "legacy shows send form and receive panel with root address" do
      get "/legacy"
      expect(last_response.body).to include("Send")
      expect(last_response.body).to include("Receive")
      expect(last_response.body).to include("Root Address")
      expect(last_response.body).to include(wallet_manager.root_address)
    end

    it "actions shows transaction table" do
      get "/actions"
      expect(last_response.body).to include("txid")
      expect(last_response.body).to include("No transactions yet")
    end

    it "settings shows session timeout form" do
      get "/settings"
      expect(last_response.body).to include("Session Timeout")
      expect(last_response.body).to include("Auto-lock after")
    end
  end

  describe "session timeout" do
    let(:app) { X100::Web.create(wallet_manager: wallet_manager, session_timeout: 2) }

    it "auto-locks after timeout expires" do
      create_wallet!
      expect(last_response.body).to include("Balance")

      sleep 2.1

      get "/"
      expect(last_response.body).to include("Unlock Wallet")
      expect(last_response.body).not_to include("Balance")
    end
  end
end
