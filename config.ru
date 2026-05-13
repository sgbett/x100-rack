# frozen_string_literal: true

require_relative "lib/x100"

storage_path = ENV.fetch("X100_STORAGE_PATH") { File.expand_path("~/.x100") }
wallet_mgr = X100::WalletManager.new(storage_path: storage_path)
app = X100::Web.create(wallet_manager: wallet_mgr)

map "/x100" do
  run app
end

# Redirect root to /x100
map "/" do
  run ->(_env) { [302, { "location" => "/x100" }, []] }
end
