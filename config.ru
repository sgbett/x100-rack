# frozen_string_literal: true

require_relative "lib/x100"

storage_path = ENV.fetch("X100_STORAGE_PATH") { File.expand_path("~/.x100") }
wallet_mgr = X100::WalletManager.new(storage_path: storage_path)
app = X100::Web.create(wallet_manager: wallet_mgr)

# Rack::URLMap sets PATH_INFO to "" for exact prefix matches (no trailing
# slash). Roda's r.root expects "/". This middleware adds the trailing slash
# redirect so /x100 → /x100/ before URLMap strips the prefix.
use(Class.new do
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/x100"
      [301, { "location" => "/x100/" }, []]
    else
      @app.call(env)
    end
  end
end)

map "/x100" do
  run app
end
