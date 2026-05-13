# frozen_string_literal: true

RSpec.describe X100::Web do
  include Rack::Test::Methods

  let(:storage_dir) { Dir.mktmpdir("x100-test") }
  let(:wallet_manager) { X100::WalletManager.new(storage_path: storage_dir) }
  let(:app) { X100::Web.create(wallet_manager: wallet_manager) }

  after { FileUtils.rm_rf(storage_dir) }

  describe "locked state" do
    context "when first run (no wallet file)" do
      it "GET / shows setup form" do
        get "/"
        expect(last_response).to be_ok
        expect(last_response.body).to include("Create Wallet")
      end

      it "GET /legacy redirects to /" do
        get "/legacy"
        expect(last_response).to be_redirect
        follow_redirect!
        expect(last_request.path).to eq "/"
      end

      it "GET /actions redirects to /" do
        get "/actions"
        expect(last_response).to be_redirect
        follow_redirect!
        expect(last_request.path).to eq "/"
      end

      it "GET /settings redirects to /" do
        get "/settings"
        expect(last_response).to be_redirect
        follow_redirect!
        expect(last_request.path).to eq "/"
      end
    end

    context "when wallet exists but locked" do
      before do
        # Create an encrypted wallet file manually
        wallet_manager.setup!(password: "testpass123")
        wallet_manager.lock!
      end

      it "GET / shows unlock form" do
        get "/"
        expect(last_response).to be_ok
        expect(last_response.body).to include("Unlock Wallet")
      end
    end
  end

  describe "POST /setup" do
    it "rejects mismatched passwords" do
      post "/setup", password: "abc", password_confirm: "xyz"
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include("Passwords do not match")
    end
  end

  describe "POST /lock" do
    before do
      wallet_manager.setup!(password: "testpass123")
    end

    it "locks the wallet and redirects to /" do
      post "/lock"
      expect(last_response).to be_redirect
      expect(wallet_manager).not_to be_unlocked
    end
  end

  describe "nav bar" do
    it "shows x100 branding" do
      get "/"
      expect(last_response.body).to include("x100")
    end

    it "shows version in footer" do
      get "/"
      expect(last_response.body).to include("x100-rack v#{X100::VERSION}")
    end

    it "disables nav links when locked" do
      get "/"
      expect(last_response.body).to include("cursor-not-allowed")
    end
  end
end
