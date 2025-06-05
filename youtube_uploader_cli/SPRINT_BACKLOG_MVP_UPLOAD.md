# Sprint Backlog: MVP Client Video Upload & Env-Key Setup

This sprint focuses on delivering the Minimum Viable Product for client video uploads,
including robust environment variable configuration and debugging capabilities.

## Sprint Goal:
Enable users to reliably authenticate and upload a single video via the CLI,
with clear configuration steps and debugging support.

---

## P0 - Critical Path / Setup

### 1. TASK: Initialize Standardized Logger
*   **Description**: Implement a centralized logger instance (Ruby `Logger`) available throughout the application. Configure it based on the `YOUTUBE_UPLOADER_LOG_LEVEL` environment variable (`DEBUG`, `INFO`, `WARN`, `ERROR`, default `INFO`). Log output should include timestamp and severity.
*   **Affected Components**: `app/cli/main.rb` (initialization), potentially a new `lib/logger.rb` or similar utility module.
*   **Clean Architecture**: Infrastructure concern, configured early. Used by all layers for consistent logging.
*   **Debugging Notes**: Essential for all subsequent debugging. Logs application startup, config loading.
*   **Depends On**: -

### 2. TASK: Enhance `CliYouTubeServiceGateway` for Authentication Logging
*   **Description**: Inject the standardized logger into `CliYouTubeServiceGateway`. Add detailed DEBUG and INFO level logs for all stages of the `authenticate` method (loading tokens, new OAuth flow, URL generation, code exchange, token storage). Log errors clearly.
*   **Affected Components**: `app/gateways/cli_youtube_service_gateway.rb`.
*   **Clean Architecture**: Gateway implementation detail.
*   **Debugging Notes**: Crucial for "Env-key setup" debugging and `youtube_upload auth` command issues.
*   **Depends On**: Task 1 (Logger)

### 3. TASK: Refine `VideoDetails` Entity
*   **Description**: Ensure `VideoDetails` entity (`app/entities/video_details.rb`) correctly handles `file_path`, `title`, `description`, `privacy_status` (with validation and default), `tags`, `category_id`. Implement a loggable `inspect` or `to_s` method.
*   **Affected Components**: `app/entities/video_details.rb`.
*   **Clean Architecture**: Core entity definition.
*   **Debugging Notes**: Clear representation of video metadata is useful in logs.
*   **Depends On**: -

### 4. TASK: Refine `UploadLogEntry` Entity
*   **Description**: Modify `UploadLogEntry` entity (`app/entities/upload_log_entry.rb`) to include `status` ('SUCCESS', 'FAILURE'), `details` (Video ID or error message), and ensure `upload_date` is ISO8601.
*   **Affected Components**: `app/entities/upload_log_entry.rb`.
*   **Clean Architecture**: Core entity definition for logging uploads.
*   **Debugging Notes**: Provides structured data for the audit log (`upload_log.csv`).
*   **Depends On**: -

## P1 - Core Upload Functionality

### 5. TASK: Implement `upload_video` Method in `CliYouTubeServiceGateway`
*   **Description**: Implement the `upload_video(video_details: Entities::VideoDetails)` method. This includes:
    *   Ensuring service is authenticated.
    *   Constructing `Google::Apis::YoutubeV3::Video` object from `video_details`.
    *   Using `@service.insert_video` to upload the file.
    *   Handling success (return video ID/response) and API errors (log and return error indicator).
    *   Inject and use the standardized logger for detailed DEBUG/INFO/ERROR logs of the upload process via API.
*   **Affected Components**: `app/gateways/cli_youtube_service_gateway.rb`.
*   **Clean Architecture**: Gateway implementation, interacts with external YouTube API.
*   **Debugging Notes**: Core of the video upload; detailed logs here are vital. Potentially investigate `google-api-client`'s own debug flags if needed (`YOUTUBE_API_DEBUG_MODE`).
*   **Depends On**: Task 1 (Logger), Task 2 (Auth Logging for `@service`), Task 3 (`VideoDetails`)

### 6. TASK: Implement `ConcreteUploadVideoUseCase`
*   **Description**: Create and implement `app/use_cases/default_upload_video.rb` (or similar name) which provides the concrete implementation for `UploadVideoUseCase` interface.
    *   Inject logger, `YouTubeServiceGateway`, and `LogPersistenceGateway`.
    *   Call `youtube_gateway.upload_video`.
    *   Create `UploadLogEntry` based on the outcome.
    *   Call `log_gateway.save`.
    *   Return a result object (success/failure) to the CLI.
    *   Log key steps at INFO/DEBUG levels.
*   **Affected Components**: New file `app/use_cases/default_upload_video.rb`, `app/use_cases/upload_video.rb` (if any adjustments to interface are needed, though unlikely).
*   **Clean Architecture**: Application-specific business logic, orchestrates gateways and entities.
*   **Debugging Notes**: Logs the flow of the upload operation from an application logic perspective.
*   **Depends On**: Task 1 (Logger), Task 4 (`UploadLogEntry`), Task 5 (`CliYouTubeServiceGateway#upload_video`), Task 7 (`LogPersistenceGateway#save`)

### 7. TASK: Refine `LogPersistenceGateway` for Detailed Logging
*   **Description**: Ensure `LogPersistenceGateway` (`app/gateways/log_persistence_gateway.rb`) correctly saves the refined `UploadLogEntry` (with status, details) to the CSV file specified by `ENV['YOUTUBE_LOG_FILE_PATH']`.
    *   Inject and use the standardized logger for its own operations (DEBUG for saving, ERROR for I/O issues).
*   **Affected Components**: `app/gateways/log_persistence_gateway.rb`.
*   **Clean Architecture**: Gateway implementation, handles interaction with the file system for audit logging.
*   **Debugging Notes**: Ensures the final audit log is accurate and helps debug file writing issues.
*   **Depends On**: Task 1 (Logger), Task 4 (`UploadLogEntry`)

### 8. TASK: Update CLI `upload` Command in `app/cli/main.rb`
*   **Description**: Modify the `upload` command in `app/cli/main.rb` to:
    *   Use the new logger.
    *   Instantiate `VideoDetails` from CLI options.
    *   Instantiate and use `DefaultUploadVideoUseCase` with all necessary gateways.
    *   Provide user feedback based on the use case result (success message with Video ID/URL, or user-friendly error).
    *   Log initial options at DEBUG level.
*   **Affected Components**: `app/cli/main.rb`.
*   **Clean Architecture**: Interface adapter, handles user input and presents output. Drives the use case.
*   **Debugging Notes**: User-facing part; logs here help trace how CLI options are passed down.
*   **Depends On**: Task 1 (Logger), Task 3 (`VideoDetails`), Task 6 (`DefaultUploadVideoUseCase`)

## P2 - Documentation & Finalization

### 9. TASK: Update `.env.example` and README for Logging Variables
*   **Description**: Add `YOUTUBE_UPLOADER_LOG_LEVEL` (and potentially `YOUTUBE_API_DEBUG_MODE` if implemented) to `youtube_uploader_cli/.env.example` with comments. Update `README.md` to explain these new debugging variables and reinforce general Env-Key setup.
*   **Affected Components**: `youtube_uploader_cli/.env.example`, `README.md`.
*   **Clean Architecture**: Documentation.
*   **Debugging Notes**: Instructs users on how to enable detailed logging.
*   **Depends On**: Task 1 (Logger), potentially Task 5 (if `YOUTUBE_API_DEBUG_MODE` is explored)

### 10. TASK: Write/Update Debugging Guide in README
*   **Description**: Add a "Debugging" section to `README.md` outlining the steps users can take to diagnose issues (check .env, enable debug log level, check auth, check upload logs, consult CSV audit log).
*   **Affected Components**: `README.md`.
*   **Clean Architecture**: Documentation.
*   **Debugging Notes**: Central place for users to find help.
*   **Depends On**: All preceding tasks as it summarizes how to debug them.

---
## Future Considerations (Out of MVP Sprint Scope):
*   More advanced error parsing from YouTube API.
*   Interactive upload progress.
*   Full test coverage for new/modified components.
*   Refined handling of `google-api-client` specific debug flags.
```
