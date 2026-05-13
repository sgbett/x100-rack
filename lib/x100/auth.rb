# frozen_string_literal: true

module X100
  # Session helpers for locked/unlocked state and timeout management.
  #
  # Mixed into the Roda app. Session stores an +unlocked_at+ timestamp;
  # each request checks whether the session has expired (default 15 min).
  # Activity resets the timer. The session does NOT store the WIF —
  # that lives only in WalletManager's process memory.
  module Auth
    DEFAULT_TIMEOUT = 900 # 15 minutes in seconds

    def session_timeout
      opts[:session_timeout] || DEFAULT_TIMEOUT
    end

    def unlocked?
      return false unless wallet_manager.unlocked?

      unlocked_at = session["unlocked_at"]
      return false unless unlocked_at

      if Time.now.to_i - unlocked_at >= session_timeout
        auto_lock!
        return false
      end

      true
    end

    def require_unlocked!
      return if unlocked?

      request.redirect "#{prefix}/"
    end

    def touch_session!
      session["unlocked_at"] = Time.now.to_i
    end

    def start_session!
      session["unlocked_at"] = Time.now.to_i
    end

    def end_session!
      session.clear
    end

    def wallet_manager
      opts[:wallet_manager]
    end

    # Returns the mount prefix (e.g. "/x100") so templates can build
    # correct URLs regardless of where the app is mounted.
    def prefix
      request.script_name
    end

    private

    def auto_lock!
      wallet_manager.lock!
      session.clear
    end
  end
end
