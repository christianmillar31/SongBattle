# SongBattle

An iOS app that helps manage and make fairer the Shazam-style music guessing game. Players split into teams and compete to identify songs and artists, with the app ensuring fair song selection and keeping track of scores.

## Features

### Game Features
- Team management
- Fair song selection system
- Scoring system (1 point for title, 1 for artist, 2 for both)
- Game session management
- Modern SwiftUI interface

### Spotify Integration
- Robust Spotify authentication and connection handling
- Reliable track filtering (excludes podcasts, shows, and advertisements)
- Thread-safe implementation
- Proper error handling and retry logic
- Comprehensive debug logging

## Technical Details
- Uses latest Spotify iOS SDK methods
- Implements proper thread safety with @MainActor
- Handles connection edge cases and timeouts
- Maintains state for played tracks to prevent repetition
- SwiftUI for the user interface
- Combine for reactive programming
- Core Data for local storage

## Requirements
- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Spotify Developer Account (for API access)

## Setup

1. Clone the repository
2. Open `SongBattle.xcodeproj` in Xcode
3. Install dependencies using Swift Package Manager
4. Configure Spotify API credentials in `Configuration.swift`
5. Build and run the project

## Development Status
The project maintains a stable checkpoint version of the Spotify integration at [SongBattle-Checkpoint](https://github.com/christianmillar31/SongBattle-Checkpoint), which serves as a reference point for the core music playback functionality.

## License
MIT License 