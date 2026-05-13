# frozen_string_literal: true

require "roda"
require "securerandom"

module X100
  # Mountable Roda app providing the wallet web UI.
  #
  # @example Mount in any Rack application
  #   wallet_mgr = X100::WalletManager.new(storage_path: "~/.x100")
  #   app = X100::Web.create(wallet_manager: wallet_mgr)
  #   map "/x100" { run app }
  class Web < Roda
    plugin :render,
           views: File.join(__dir__, "..", "..", "views"),
           engine: "erb",
           layout: "layout"
    plugin :sessions,
           secret: ENV.fetch("X100_SESSION_SECRET") { SecureRandom.hex(32) }
    plugin :slash_path_empty

    include Auth

    # Create a configured instance of the app.
    # Returns a Roda subclass with wallet_manager set in opts.
    def self.create(wallet_manager:, session_timeout: nil)
      app = Class.new(self)
      app.opts[:wallet_manager] = wallet_manager
      app.opts[:session_timeout] = session_timeout if session_timeout
      app
    end

    route do |r| # rubocop:disable Metrics/BlockLength
      touch_session! if unlocked?

      r.root do
        view "home"
      end

      r.on "legacy" do
        r.get do
          require_unlocked!
          view "legacy"
        end
      end

      r.on "actions" do
        r.get do
          require_unlocked!
          view "actions"
        end
      end

      r.on "settings" do
        r.get do
          require_unlocked!
          view "settings"
        end
      end

      r.post "unlock" do
        password = r.params["password"].to_s
        begin
          wallet_manager.unlock!(password: password)
          start_session!
        rescue RuntimeError => e
          session["flash_error"] = e.message
        end
        r.redirect "#{prefix}/"
      end

      r.post "setup" do
        password = r.params["password"].to_s
        password_confirm = r.params["password_confirm"].to_s

        if password.empty? || password != password_confirm
          session["flash_error"] = "Passwords do not match"
          r.redirect "#{prefix}/"
        end

        begin
          wif = wallet_manager.setup!(password: password)
          session["show_wif"] = wif
          start_session!
        rescue RuntimeError => e
          session["flash_error"] = e.message
        end
        r.redirect "#{prefix}/"
      end

      r.post "lock" do
        wallet_manager.lock!
        end_session!
        r.redirect "#{prefix}/"
      end
    end
  end
end
