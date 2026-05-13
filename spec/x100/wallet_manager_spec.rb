# frozen_string_literal: true

require "tmpdir"

RSpec.describe X100::WalletManager do
  let(:storage_dir) { Dir.mktmpdir("x100-test") }
  subject(:manager) { described_class.new(storage_path: storage_dir) }

  after { FileUtils.rm_rf(storage_dir) }

  describe "#first_run?" do
    it "returns true when no wallet file exists" do
      expect(manager).to be_first_run
    end

    it "returns false after setup" do
      manager.setup!(password: "testpass")
      manager.lock!
      expect(manager).not_to be_first_run
    end
  end

  describe "#setup!" do
    it "creates an encrypted wallet file" do
      manager.setup!(password: "testpass")
      expect(File.exist?(File.join(storage_dir, "wallet.enc"))).to be true
    end

    it "returns the WIF" do
      wif = manager.setup!(password: "testpass")
      expect(wif).to start_with("L").or start_with("K")
    end

    it "leaves the wallet unlocked" do
      manager.setup!(password: "testpass")
      expect(manager).to be_unlocked
    end

    it "raises if wallet already exists" do
      manager.setup!(password: "testpass")
      manager.lock!
      expect { manager.setup!(password: "testpass") }.to raise_error("Wallet already exists")
    end

    it "sets restrictive file permissions" do
      manager.setup!(password: "testpass")
      mode = File.stat(File.join(storage_dir, "wallet.enc")).mode & 0o777
      expect(mode).to eq 0o600
    end
  end

  describe "#unlock!" do
    before do
      manager.setup!(password: "testpass")
      manager.lock!
    end

    it "unlocks with the correct password" do
      manager.unlock!(password: "testpass")
      expect(manager).to be_unlocked
    end

    it "raises on wrong password" do
      expect { manager.unlock!(password: "wrong") }.to raise_error("Invalid password")
    end

    it "raises if already unlocked" do
      manager.unlock!(password: "testpass")
      expect { manager.unlock!(password: "testpass") }.to raise_error("Already unlocked")
    end

    it "raises if no wallet file exists" do
      fresh = described_class.new(storage_path: Dir.mktmpdir("x100-fresh"))
      expect { fresh.unlock!(password: "testpass") }.to raise_error("Wallet not set up")
    end
  end

  describe "#lock!" do
    it "clears the engine" do
      manager.setup!(password: "testpass")
      manager.lock!
      expect(manager).not_to be_unlocked
    end
  end

  describe "#engine" do
    it "raises when locked" do
      expect { manager.engine }.to raise_error("Wallet is locked")
    end
  end

  describe "#balance" do
    it "returns 0 when locked" do
      expect(manager.balance).to eq 0
    end
  end
end
