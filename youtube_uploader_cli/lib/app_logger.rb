require 'logger'
require 'date' # Required for ISO8601 timestamp

module AppLogger
  class << self
    attr_accessor :logger
  end

  def self.initialize_logger
    @logger = Logger.new(STDOUT)
    @logger.level = get_log_level
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      # Ensure datetime is a DateTime object for iso8601 method
      dt = datetime.is_a?(DateTime) ? datetime : datetime.to_datetime
      timestamp = dt.iso8601(3) # ISO8601 format with milliseconds
      "[#{timestamp} #{severity}] #{msg}\n"
    end
    @logger
  end

  def self.get_log_level
    level_str = ENV['YOUTUBE_UPLOADER_LOG_LEVEL']&.upcase
    case level_str
    when 'DEBUG'
      Logger::DEBUG
    when 'INFO'
      Logger::INFO
    when 'WARN'
      Logger::WARN
    when 'ERROR'
      Logger::ERROR
    else
      Logger::INFO # Default level
    end
  end

  # Initialize the logger when the module is loaded
  initialize_logger unless @logger
end
