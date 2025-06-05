# frozen_string_literal: true

require_relative '../entities/upload_log_entry'

module Gateways
  # Module defining the contract for a Log Persistence Gateway.
  # Concrete implementations will handle how log entries are stored (e.g., CSV, database).
  # This interface is simple to allow for various backend implementations.
  module LogPersistenceGateway
    # Saves a log entry.
    #
    # @param log_entry [Entities::UploadLogEntry] The log entry entity to persist.
    # @return [Object] The result of the save operation (e.g., :success, or the saved record ID).
    #   Can raise an error on failure.
    def save(log_entry:)
      raise NotImplementedError, "\#{self.class} has not implemented method '#{__method__}'"
    end

    module_function :save
  end
end
