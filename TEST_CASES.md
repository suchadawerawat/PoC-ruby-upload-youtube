# Test Cases for YouTube Uploader CLI

This document outlines test cases for the YouTube Uploader CLI, derived from the user flow diagram and command specifications.

## 1. Authentication (`youtube_upload auth`)

### TC_AUTH_001: Successful Authentication and Token Storage
*   **Description:** Verifies that a user can successfully authenticate with Google and the CLI stores the obtained tokens.
*   **Preconditions:**
    *   Valid `client_secret.json` is in the `config/` directory.
    *   User has a valid Google account with YouTube access.
*   **Steps:**
    1.  Execute command: `youtube_upload auth`
    2.  CLI prompts user to open a URL.
    3.  User opens the URL in a browser.
    4.  User authenticates with Google and grants the requested permissions.
    5.  Browser redirects or provides an authorization code that is passed to the CLI.
    6.  CLI exchanges the code for access and refresh tokens.
    7.  CLI stores the tokens (e.g., in `config/tokens.yaml`).
*   **Expected Result:**
    *   CLI displays a message like "Authentication successful!"
    *   Token file (e.g., `config/tokens.yaml`) is created/updated with valid tokens.

### TC_AUTH_002: Authentication Failure - User Denies Consent
*   **Description:** Verifies that authentication fails gracefully if the user denies consent in the Google authentication flow.
*   **Preconditions:**
    *   Valid `client_secret.json` is in the `config/` directory.
*   **Steps:**
    1.  Execute command: `youtube_upload auth`
    2.  CLI prompts user to open a URL.
    3.  User opens the URL in a browser.
    4.  User authenticates with Google but *denies* consent/permissions.
*   **Expected Result:**
    *   CLI displays an authentication failure message (e.g., "Authentication failed: Consent denied by user.").
    *   No token file is created or modified if it already exists.

### TC_AUTH_003: Authentication Failure - Network Issue During Token Exchange
*   **Description:** Verifies that authentication fails if the CLI cannot communicate with GoogleAuth to exchange the authorization code for tokens (e.g., due to a network error).
*   **Preconditions:**
    *   Valid `client_secret.json` is in the `config/` directory.
*   **Steps:**
    1.  Execute command: `youtube_upload auth`
    2.  CLI prompts user to open a URL.
    3.  User opens the URL, authenticates, and grants consent.
    4.  Authorization code is received by the CLI.
    5.  Simulate a network failure preventing the CLI from reaching Google's token endpoint.
*   **Expected Result:**
    *   CLI displays an authentication failure message (e.g., "Authentication failed: Could not connect to Google services to exchange token.").
    *   No token file is created or modified.

### TC_AUTH_004: Authentication Failure - Invalid Authorization Code
*   **Description:** Verifies that authentication fails if the CLI attempts to use an invalid, expired, or already used authorization code.
*   **Preconditions:**
    *   Valid `client_secret.json` is in the `config/` directory.
*   **Steps:**
    1.  Execute command: `youtube_upload auth`
    2.  CLI prompts user to open a URL.
    3.  User opens the URL, authenticates, and grants consent.
    4.  Authorization code is received by the CLI.
    5.  Manually alter the code to be invalid before the CLI uses it, or attempt to reuse an old code.
*   **Expected Result:**
    *   CLI displays an authentication failure message from Google (e.g., "Authentication failed: Invalid grant." or similar error).
    *   No token file is created or modified.

## 2. Video Upload (`youtube_upload upload`)

### TC_UPLOAD_001: Successful Video Upload - Minimal Options
*   **Description:** Verifies a successful video upload using only the required file path.
*   **Preconditions:**
    *   User is authenticated (valid tokens exist in `config/tokens.yaml`).
    *   A valid video file (e.g., `test_video.mp4`) exists.
*   **Steps:**
    1.  Execute command: `youtube_upload upload test_video.mp4`
*   **Expected Result:**
    *   CLI displays "Video uploaded successfully: <video_link>".
    *   The video is uploaded to YouTube with default settings (e.g., private, title matching filename).

### TC_UPLOAD_002: Successful Video Upload - All Valid Options
*   **Description:** Verifies a successful video upload with all available valid options specified.
*   **Preconditions:**
    *   User is authenticated.
    *   A valid video file (e.g., `test_video.mp4`) exists.
*   **Steps:**
    1.  Execute command: `youtube_upload upload test_video.mp4 -t "My Awesome Test Video" -d "This is a detailed description of my video." -c "22" -p "public" -g "test,cli,youtube_upload,sample tag"`
    (Note: "22" is "People & Blogs", ensure this is a valid and available category ID in the test environment)
*   **Expected Result:**
    *   CLI displays "Video uploaded successfully: <video_link>".
    *   The video is uploaded to YouTube with the specified title, description, category, privacy status (public), and tags.

### TC_UPLOAD_003: Successful Video Upload - Unlisted Privacy
*   **Description:** Verifies a successful video upload with 'unlisted' privacy status.
*   **Preconditions:**
    *   User is authenticated.
    *   A valid video file (e.g., `test_video.mp4`) exists.
*   **Steps:**
    1.  Execute command: `youtube_upload upload test_video.mp4 -p "unlisted"`
*   **Expected Result:**
    *   CLI displays "Video uploaded successfully: <video_link>".
    *   The video is uploaded to YouTube with 'unlisted' privacy.

### TC_UPLOAD_004: Upload Failure - File Not Found
*   **Description:** Verifies that the upload fails if the specified video file does not exist.
*   **Preconditions:**
    *   User is authenticated.
*   **Steps:**
    1.  Execute command: `youtube_upload upload non_existent_video.mp4`
*   **Expected Result:**
    *   CLI displays an error message (e.g., "Error: Video file not found: non_existent_video.mp4").
    *   No upload attempt is made to YouTube.

### TC_UPLOAD_005: Upload Failure - Invalid Video File Format (API Rejection)
*   **Description:** Verifies that the upload fails if the file is not a valid video format recognized by YouTube.
*   **Preconditions:**
    *   User is authenticated.
    *   A non-video file exists (e.g., `document.txt`).
*   **Steps:**
    1.  Execute command: `youtube_upload upload document.txt`
*   **Expected Result:**
    *   CLI displays an error message from the YouTube API indicating an invalid file type or processing error (e.g., "Upload failed: The file type is not supported." or "Video processing failed.").

### TC_UPLOAD_006: Upload Failure - Invalid Category ID
*   **Description:** Verifies that the upload fails or defaults if an invalid category ID is provided.
*   **Preconditions:**
    *   User is authenticated.
    *   A valid video file exists.
*   **Steps:**
    1.  Execute command: `youtube_upload upload test_video.mp4 -c "INVALID_CATEGORY"`
*   **Expected Result:**
    *   CLI displays an error message (e.g., "Error: Invalid category ID 'INVALID_CATEGORY'. Please provide a numeric ID.") or the YouTube API rejects it. If the CLI doesn't validate, the API error should be reported.

### TC_UPLOAD_007: Upload Failure - Invalid Privacy Status
*   **Description:** Verifies that the upload fails if an invalid privacy status string is provided.
*   **Preconditions:**
    *   User is authenticated.
    *   A valid video file exists.
*   **Steps:**
    1.  Execute command: `youtube_upload upload test_video.mp4 -p "semi-private"`
*   **Expected Result:**
    *   CLI displays an error message (e.g., "Error: Invalid privacy status 'semi-private'. Allowed values are: public, private, unlisted.").

### TC_UPLOAD_008: Upload Failure - Not Authenticated
*   **Description:** Verifies that video upload fails if the user has not authenticated (no tokens).
*   **Preconditions:**
    *   No valid authentication tokens are stored (e.g., `config/tokens.yaml` is missing or empty).
    *   A valid video file exists.
*   **Steps:**
    1.  Execute command: `youtube_upload upload test_video.mp4`
*   **Expected Result:**
    *   CLI displays an error message (e.g., "Error: Authentication required. Please run `youtube_upload auth` first.").

### TC_UPLOAD_009: Upload Failure - Expired/Invalid Tokens
*   **Description:** Verifies that video upload fails if the stored authentication tokens are expired or invalid.
*   **Preconditions:**
    *   Stored authentication tokens in `config/tokens.yaml` are expired or manually corrupted.
    *   A valid video file exists.
*   **Steps:**
    1.  Execute command: `youtube_upload upload test_video.mp4`
*   **Expected Result:**
    *   CLI attempts upload, but YouTube API rejects it due to token invalidity.
    *   CLI displays an error message (e.g., "Error: YouTube API authentication failed. Your tokens might be invalid or expired. Please re-authenticate using `youtube_upload auth`.").

## 3. General CLI Commands

### TC_GEN_001: Display Version
*   **Description:** Verifies that the CLI can display its version information.
*   **Steps:**
    1.  Execute command: `youtube_upload version`
    2.  Execute command: `youtube_upload --version`
    3.  Execute command: `youtube_upload -v`
*   **Expected Result:**
    *   For each command, the CLI prints its version (e.g., "youtube_upload version 1.0.0").

### TC_GEN_002: Display General Help
*   **Description:** Verifies that the CLI can display the main help message.
*   **Steps:**
    1.  Execute command: `youtube_upload help`
    2.  Execute command: `youtube_upload -h`
*   **Expected Result:**
    *   For each command, the CLI displays a general help message listing available commands, options, and usage instructions.

### TC_GEN_003: Display Command-Specific Help - `auth`
*   **Description:** Verifies that the CLI can display help for the `auth` command.
*   **Steps:**
    1.  Execute command: `youtube_upload help auth`
*   **Expected Result:**
    *   CLI displays detailed help information specific to the `auth` command, including its purpose and any options.

### TC_GEN_004: Display Command-Specific Help - `upload`
*   **Description:** Verifies that the CLI can display help for the `upload` command.
*   **Steps:**
    1.  Execute command: `youtube_upload help upload`
*   **Expected Result:**
    *   CLI displays detailed help information specific to the `upload` command, including all its parameters (file path, title, description, category, privacy, tags) and their usage.
