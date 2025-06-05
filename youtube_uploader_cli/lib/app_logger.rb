require 'logger'

module AppLogger
  def self.get_logger
    logger = Logger.new(STDOUT)
    logger.formatter = proc do |severity, datetime, _progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
    end

    log_level = ENV['YOUTUBE_UPLOADER_LOG_LEVEL']&.upcase
    case log_level
    when 'DEBUG'
      logger.level = Logger::DEBUG
    when 'INFO'
      logger.level = Logger::INFO
    when 'WARN'
      logger.level = Logger::WARN
    when 'ERROR'
      logger.level = Logger::ERROR
    else
      logger.level = Logger::INFO
    end

    logger
  end
end
