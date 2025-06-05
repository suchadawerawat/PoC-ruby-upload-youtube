# frozen_string_literal: true

require_relative '../entities/upload_log_entry'
# Forward declare gateway module
module Gateways
  module LogPersistenceGateway
  end
end

module UseCases
  # Module defining the contract for the LogUploadDetails use case.
  # Concrete implementations will handle persisting upload log entries.
  module LogUploadDetailsUseCase
    # Executes the logging process for an upload.
    #
    # @param log_entry [Entities::UploadLogEntry] The log entry to persist.
    # @param log_gateway [Gateways::LogPersistenceGateway] The gateway for persisting log information.
    # @return [Object] The result of the logging attempt.
    def execute(log_entry:, log_gateway:)
      raise NotImplementedError, "\#{self.class} has not implemented method '#{__method__}'"
    end
    module_function :execute
  end
end
