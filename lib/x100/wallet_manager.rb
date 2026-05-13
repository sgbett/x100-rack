# frozen_string_literal: true

require "openssl"
require "json"
require "fileutils"

module X100
  # Manages the wallet engine lifecycle: setup, unlock, lock.
  #
  # On first run, generates a new private key, encrypts it with a
  # user-provided password, and persists the encrypted WIF to disk.
  # On subsequent runs, decrypts the WIF and boots the wallet engine.
  #
  # The engine lives at the app level (not per-request) because
  # constructing it is expensive (DB connection, key derivation).
  class WalletManager
    PBKDF2_ITERATIONS = 100_000
    CIPHER = "aes-256-gcm"

    attr_reader :storage_path, :identity_key

    def initialize(storage_path: File.expand_path("~/.x100"))
      @storage_path = storage_path
      @engine = nil
      @utxo_pool = nil
      @identity_key = nil
      @wif = nil
      @mutex = Mutex.new
    end

    def first_run?
      !File.exist?(encrypted_wif_path)
    end

    def unlocked?
      !@wif.nil?
    end

    # Generate a new private key, encrypt with password, persist.
    # Returns the WIF for the user to record as their recovery phrase.
    def setup!(password:)
      raise "Wallet already exists" unless first_run?

      require "bsv-sdk"
      private_key = BSV::Primitives::PrivateKey.generate
      wif = private_key.to_wif

      encrypt_and_store!(wif, password)
      activate!(wif)

      wif
    end

    # Decrypt WIF from disk and activate the wallet.
    def unlock!(password:)
      raise "Wallet not set up" if first_run?
      raise "Already unlocked" if unlocked?

      wif = decrypt_wif(password)
      activate!(wif)
      true
    end

    # Clear key material from memory.
    def lock!
      @mutex.synchronize do
        @engine = nil
        @utxo_pool = nil
        @identity_key = nil
        @wif = nil
      end
    end

    # Returns the engine, booting it on first access if DATABASE_URL is available.
    # Raises if the wallet is locked.
    def engine
      raise "Wallet is locked" unless unlocked?

      @engine || boot_engine!
    end

    def balance
      return 0 unless unlocked?

      @utxo_pool&.balance || 0
    end

    private

    def encrypted_wif_path
      File.join(@storage_path, "wallet.enc")
    end

    # Store the decrypted WIF and derive identity key.
    # Engine boot is deferred until engine is actually accessed.
    def activate!(wif)
      @mutex.synchronize do
        require "bsv-sdk"
        @wif = wif
        private_key = BSV::Primitives::PrivateKey.from_wif(wif)
        @identity_key = private_key.public_key.to_hex
      end
    end

    # Boot the full wallet engine (requires DATABASE_URL and bsv-wallet-postgres).
    def boot_engine!
      @mutex.synchronize do
        return @engine if @engine

        require "sequel"
        require "bsv-wallet"
        require "bsv-wallet-postgres"

        private_key = BSV::Primitives::PrivateKey.from_wif(@wif)
        key_deriver = BSV::Wallet::KeyDeriver.new(private_key: private_key)

        db_url = ENV.fetch("DATABASE_URL") { raise "Set DATABASE_URL to boot the wallet engine" }
        db = Sequel.connect(db_url)
        db.extension :pg_enum
        db.extension :pg_array
        db.extension :pg_json
        BSV::Wallet::Postgres.connect(db)

        Sequel.extension :migration
        migrations_path = File.join(
          Gem::Specification.find_by_name("bsv-wallet-postgres").gem_dir,
          "db", "migrations"
        )
        Sequel::Migrator.run(db, migrations_path)

        store = BSV::Wallet::Postgres::Store.new(db: db)
        proof_store = BSV::Wallet::Postgres::ProofStore.new(db: db)
        @utxo_pool = BSV::Wallet::Postgres::UTXOPool.new(store: store)

        network_provider = BSV::Network::Providers::WhatsOnChain.mainnet
        services = BSV::Network::Services.new(providers: [network_provider])
        chain_tracker = BSV::Network::ChainTracker.new(db: db, services: services)

        @engine = BSV::Wallet::Engine.new(
          store: store,
          utxo_pool: @utxo_pool,
          broadcast_queue: BSV::Wallet::Postgres::BroadcastQueue.new(db: db),
          proof_store: proof_store,
          key_deriver: key_deriver,
          chain_tracker: chain_tracker,
          network_provider: network_provider,
          network: :mainnet
        )
      end
    end

    def encrypt_and_store!(wif, password)
      FileUtils.mkdir_p(@storage_path, mode: 0o700)

      salt = OpenSSL::Random.random_bytes(32)
      key = derive_key(password, salt)

      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.encrypt
      cipher.key = key
      iv = cipher.random_iv
      cipher.auth_data = ""

      ciphertext = cipher.update(wif) + cipher.final
      auth_tag = cipher.auth_tag

      payload = {
        salt: salt.unpack1("H*"),
        iv: iv.unpack1("H*"),
        ciphertext: ciphertext.unpack1("H*"),
        auth_tag: auth_tag.unpack1("H*")
      }

      File.write(encrypted_wif_path, JSON.generate(payload))
      File.chmod(0o600, encrypted_wif_path)
    end

    def decrypt_wif(password)
      payload = JSON.parse(File.read(encrypted_wif_path))

      salt = [payload["salt"]].pack("H*")
      iv = [payload["iv"]].pack("H*")
      ciphertext = [payload["ciphertext"]].pack("H*")
      auth_tag = [payload["auth_tag"]].pack("H*")

      key = derive_key(password, salt)

      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_tag = auth_tag
      cipher.auth_data = ""

      cipher.update(ciphertext) + cipher.final
    rescue OpenSSL::Cipher::CipherError
      raise "Invalid password"
    end

    def derive_key(password, salt)
      OpenSSL::KDF.pbkdf2_hmac(
        password,
        salt: salt,
        iterations: PBKDF2_ITERATIONS,
        length: 32,
        hash: "SHA256"
      )
    end
  end
end
