# YouTube Uploader CLI

A Ruby CLI tool to upload videos to YouTube and log the uploads.

## Architectural Overview

This project follows the principles of **Clean Architecture** to ensure a separation of concerns, testability, and adaptability. The main layers are:

\`\`\`mermaid
graph TD
    subgraph "Frameworks & Drivers (Outer Layer)"
        A1[CLI (Thor)]
        A2[Google API Client Gem]
        A3[File System]
        A4[Future: Rails UI]
        A5[Future: Database Adapters (PG, MySQL)]
    end

    subgraph "Interface Adapters (Gateways & Controllers)"
        B1[CLI Controller (app/cli)]
        B2[YouTubeServiceGateway (app/gateways)]
        B3[LogPersistenceGateway (app/gateways)]
    end

    subgraph "Application Business Rules (Use Cases)"
        C1[UploadVideoUseCase (app/use_cases)]
        C2[LogUploadDetailsUseCase (app/use_cases)]
    end

    subgraph "Enterprise Business Rules (Entities)"
        D1[VideoDetails (app/entities)]
        D2[UploadLogEntry (app/entities)]
    end

    %% Dependencies (Arrows point inwards)
    A1 --> B1
    A2 -.-> B2 %% Gem is used by Gateway Impl
    A3 -.-> B2 %% FS for video file
    A3 -.-> B3 %% FS for log file (initially)

    B1 --> C1
    B1 --> C2
    B2 --> C1 %% UseCase uses Gateway Interface
    B3 --> C1 %% UseCase uses Gateway Interface
    B3 --> C2 %% UseCase uses Gateway Interface

    C1 --> D1 %% UseCase uses Entity
    C1 --> D2 %% UseCase uses Entity (indirectly via LogUpload)
    C2 --> D2 %% UseCase uses Entity

    %% Future dependencies
    A4 -.-> C1
    A4 -.-> C2
    A5 -.-> B3

    style A1 fill:#f9f,stroke:#333,stroke-width:2px
    style A2 fill:#f9f,stroke:#333,stroke-width:2px
    style A3 fill:#f9f,stroke:#333,stroke-width:2px
    style A4 fill:#lightgrey,stroke:#333,stroke-width:2px,stroke-dasharray: 5 5
    style A5 fill:#lightgrey,stroke:#333,stroke-width:2px,stroke-dasharray: 5 5

    style B1 fill:#ccf,stroke:#333,stroke-width:2px
    style B2 fill:#ccf,stroke:#333,stroke-width:2px
    style B3 fill:#ccf,stroke:#333,stroke-width:2px

    style C1 fill:#9cf,stroke:#333,stroke-width:2px
    style C2 fill:#9cf,stroke:#333,stroke-width:2px

    style D1 fill:#9fc,stroke:#333,stroke-width:2px
    style D2 fill:#9fc,stroke:#333,stroke-width:2px

    linkStyle default interpolate basis
\`\`\`

**Key Principles:**

*   **Dependency Rule:** Dependencies only point inwards. Entities are at the core, followed by Use Cases, then Gateways, and finally Frameworks/Drivers on the outside.
*   **Abstractions:** Use Cases depend on Gateway *interfaces*, not concrete implementations. This allows flexibility (e.g., changing from a CSV logger to a database logger without altering the Use Case).
*   **Testability:** Each layer can be tested independently. Inner layers don't know about outer layers, making unit testing of business logic straightforward.

This structure is designed to make the application:
-   **Easy to maintain:** Changes in one area (e.g., UI or database) have minimal impact on others.
-   **Adaptable:** New features or integrations (like a Rails frontend or different database backends) can be added by creating new implementations for the outer layers or gateways without disrupting the core logic.
-   **Testable:** Core business logic is independent of external concerns.

## Prerequisites

Before you begin, ensure you have the following installed:

*   **Ruby:** Version 2.7 or higher is recommended. You can check your version with `ruby -v`. (Installation: [https://www.ruby-lang.org/en/documentation/installation/](https://www.ruby-lang.org/en/documentation/installation/))
*   **Bundler:** This is a Ruby gem for managing application dependencies. You can install it with `gem install bundler`. (Installation: [https://bundler.io/](https://bundler.io/))

## Google Cloud Project Setup

To use this tool, you'll need to authorize it to access your YouTube account. This involves setting up a project on Google Cloud Platform and enabling the YouTube Data API.

1.  **Create or Select a Google Cloud Project:**
    *   Go to the [Google Cloud Console](https://console.cloud.google.com/).
    *   If you don't have an existing project, create a new one by clicking the project dropdown and then "New Project". Give it a descriptive name.

2.  **Enable the YouTube Data API v3:**
    *   In the Google Cloud Console, navigate to "APIs & Services" > "Library".
    *   Search for "YouTube Data API v3".
    *   Select it and click "Enable".

3.  **Create OAuth 2.0 Credentials:**
    *   Go to "APIs & Services" > "Credentials".
    *   Click "+ CREATE CREDENTIALS" and select "OAuth client ID".
    *   If prompted, you might need to configure the "OAuth consent screen" first:
        *   Choose "User Type" (likely "External" if you're testing with a personal account, or "Internal" if you're part of a Google Workspace organization).
        *   Fill in the required fields: App name (e.g., "Ruby YouTube Uploader CLI"), User support email, and Developer contact information. Click "SAVE AND CONTINUE" through the Scopes and Test users sections for now (scopes will be handled by the application).
    *   Once the consent screen is configured (or if you didn't need to), select "Desktop app" as the "Application type".
    *   Give your client ID a name (e.g., "YouTube Uploader CLI Desktop Client").
    *   Click "CREATE".

4.  **Download Client Secret JSON:**
    *   After creating the OAuth client ID, a dialog will show your Client ID and Client Secret. You don't need to copy these directly.
    *   Find your newly created "Desktop app" client in the "OAuth 2.0 Client IDs" list.
    *   Click the download icon (looks like a downward arrow) next to it. This will download a JSON file, usually named something like `client_secret_XXXXXXXXXXXX.json`.
    *   **Rename this file to `client_secret.json`**.
    *   **Place this `client_secret.json` file into the `config/` directory within this project.** (i.e., `youtube_uploader_cli/config/client_secret.json`)

    **Important Security Note:** The `client_secret.json` file contains sensitive credentials. It should **NEVER** be committed to version control. Ensure your project's `.gitignore` file includes `config/client_secret.json`. (This will be handled in a later step if not already present).


## Prerequisites

Before you begin, ensure you have the following installed:

*   **Ruby:** Version 2.7 or higher is recommended. You can check your version with `ruby -v`. (Installation: [https://www.ruby-lang.org/en/documentation/installation/](https://www.ruby-lang.org/en/documentation/installation/))
*   **Bundler:** This is a Ruby gem for managing application dependencies. You can install it with `gem install bundler`. (Installation: [https://bundler.io/](https://bundler.io/))

## Google Cloud Project Setup

To use this tool, you'll need to authorize it to access your YouTube account. This involves setting up a project on Google Cloud Platform and enabling the YouTube Data API.

1.  **Create or Select a Google Cloud Project:**
    *   Go to the [Google Cloud Console](https://console.cloud.google.com/).
    *   If you don't have an existing project, create a new one by clicking the project dropdown and then "New Project". Give it a descriptive name.

2.  **Enable the YouTube Data API v3:**
    *   In the Google Cloud Console, navigate to "APIs & Services" > "Library".
    *   Search for "YouTube Data API v3".
    *   Select it and click "Enable".

3.  **Create OAuth 2.0 Credentials:**
    *   Go to "APIs & Services" > "Credentials".
    *   Click "+ CREATE CREDENTIALS" and select "OAuth client ID".
    *   If prompted, you might need to configure the "OAuth consent screen" first:
        *   Choose "User Type" (likely "External" if you're testing with a personal account, or "Internal" if you're part of a Google Workspace organization).
        *   Fill in the required fields: App name (e.g., "Ruby YouTube Uploader CLI"), User support email, and Developer contact information. Click "SAVE AND CONTINUE" through the Scopes and Test users sections for now (scopes will be handled by the application).
    *   Once the consent screen is configured (or if you didn't need to), select "Desktop app" as the "Application type".
    *   Give your client ID a name (e.g., "YouTube Uploader CLI Desktop Client").
    *   Click "CREATE".

4.  **Download Client Secret JSON:**
    *   After creating the OAuth client ID, a dialog will show your Client ID and Client Secret. You don't need to copy these directly.
    *   Find your newly created "Desktop app" client in the "OAuth 2.0 Client IDs" list.
    *   Click the download icon (looks like a downward arrow) next to it. This will download a JSON file, usually named something like `client_secret_XXXXXXXXXXXX.json`.
    *   **Rename this file to `client_secret.json`**.
    *   **Place this `client_secret.json` file into the `config/` directory within this project.** (i.e., `youtube_uploader_cli/config/client_secret.json`)

    **Important Security Note:** The `client_secret.json` file contains sensitive credentials. It should **NEVER** be committed to version control. Ensure your project's `.gitignore` file includes `config/client_secret.json`. (This will be handled in a later step if not already present).


## Environment Variables

This project uses a `.env` file to manage environment-specific configurations, such as API key paths and log file locations. This file is not committed to version control, allowing each user to have their own settings.

To set up your local environment:

1.  **Create a `.env` file:** In the root of the project, create a file named `.env`.
2.  **Copy from example:** Copy the contents of `.env.example` (see below) into your new `.env` file.
3.  **Customize values:** Adjust the values in your `.env` file as needed for your setup.

The application uses the `dotenv` gem to automatically load these variables when it starts.
