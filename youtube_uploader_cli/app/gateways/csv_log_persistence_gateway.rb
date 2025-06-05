# frozen_string_literal: true

require 'csv'
require 'fileutils'
require_relative '../entities/upload_log_entry'
require_relative 'log_persistence_gateway'

module Gateways
  # Concrete implementation of LogPersistenceGateway using a CSV file.
  class CsvLogPersistenceGateway
    include LogPersistenceGateway # Ensure it adheres to the interface

    DEFAULT_LOG_FILE_PATH = 'logs/upload_log.csv'.freeze
    CSV_HEADERS = ['Upload Date', 'File Path', 'Video Title', 'Status', 'Details', 'YouTube URL'].freeze

    # @param logger [Logger] The application logger.
    # @param log_file_path [String] Path to the CSV log file. Defaults to DEFAULT_LOG_FILE_PATH.
    def initialize(logger:, log_file_path: nil)
      @logger = logger
      @log_file_path = log_file_path || DEFAULT_LOG_FILE_PATH
      @logger.info("CsvLogPersistenceGateway initialized. Log file: #{@log_file_path}")
      ensure_log_file_exists_with_headers
    end

    # Saves an UploadLogEntry to the CSV file.
    #
    # @param log_entry [Entities::UploadLogEntry] The log entry to save.
    # @return [:success] If saving was successful.
    # @raise [StandardError] If an I/O error or other exception occurs.
    def save(log_entry:) # Ensure method signature matches interface (keyword arg)
      @logger.debug("Attempting to save log entry: #{log_entry.to_h.inspect}")

      begin
        # CSV.open will create the file if it doesn't exist, but we want to manage headers explicitly.
        # ensure_log_file_exists_with_headers handles creation and headers.
        CSV.open(@log_file_path, 'a', write_headers: false) do |csv| # 'a' for append
          csv << log_entry.to_csv_row # Use the entity's method to get the row
        end
        @logger.info("Successfully saved log entry to #{@log_file_path}")
        :success
      rescue CSV::MalformedCSVError => e
        @logger.error("CSV formatting error while saving log to #{@log_file_path}: #{e.message}")
        raise # Re-raise to indicate failure to the use case
      rescue SystemCallError => e # Catches most I/O errors like Errno::EACCES, Errno::ENOSPC
        @logger.error("I/O error while saving log to #{@log_file_path}: #{e.message} (Error Code: #{e.errno})")
        raise # Re-raise to indicate failure to the use case
      rescue StandardError => e
        @logger.error("Unexpected error while saving log to #{@log_file_path}: #{e.message}")
        @logger.error("Backtrace: #{e.backtrace.join("\n")}")
        raise # Re-raise to indicate failure to the use case
      end
    end

    private

    def ensure_log_file_exists_with_headers
      log_dir = File.dirname(@log_file_path)
      FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
      @logger.debug("Ensured log directory exists: #{log_dir}")

      if File.exist?(@log_file_path)
        @logger.debug("Log file #{@log_file_path} already exists.")
        # Check if headers are present, if not, add them (e.g., if file was empty or manually created)
        # This is a simple check; could be more robust (e.g., read first line and compare)
        if File.zero?(@log_file_path) || CSV.read(@log_file_path, headers: true).headers != CSV_HEADERS
            @logger.info("Log file #{@log_file_path} is empty or missing headers. Writing headers.")
            write_headers
        end
      else
        @logger.info("Log file #{@log_file_path} does not exist. Creating with headers.")
        write_headers
      end
    rescue SystemCallError => e
        @logger.error("Failed to ensure log file #{@log_file_path} exists with headers due to I/O error: #{e.message}")
        raise
    end

    def write_headers
      CSV.open(@log_file_path, 'w', write_headers: true, headers: CSV_HEADERS) do |csv|
        # Headers are written automatically due to `write_headers: true` and `headers: CSV_HEADERS`
        # No need to explicitly write `csv << CSV_HEADERS` if `write_headers: true` is used with `headers:`
      end
      @logger.info("Wrote CSV headers to #{@log_file_path}")
    rescue SystemCallError => e
        @logger.error("Failed to write headers to log file #{@log_file_path} due to I/O error: #{e.message}")
        raise
    end
  end
end
