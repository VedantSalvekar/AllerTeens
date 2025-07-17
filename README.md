# AllerWise - AI-Powered Allergy Training App

A Flutter application with integrated AI conversation system for allergy training and education.

## Features

- **AI Conversation System**: OpenAI GPT-3.5 Turbo integration with conversation context
- **Neural TTS**: Realistic voice synthesis using OpenAI's Text-to-Speech API
- **Dual Spritesheet Animation**: Character animation system with talking/non-talking states
- **Speech Recognition**: Speech-to-text with enhanced error handling
- **Synchronized Subtitles**: Real-time subtitle timing with TTS callbacks
- **Restaurant Simulation**: Interactive restaurant environment with ambient audio
- **Firebase Authentication**: Complete user management system
- **Allergy Management**: Comprehensive allergy tracking and education

## Setup Instructions

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Firebase project with Authentication and Firestore enabled
- OpenAI API key

### Installation

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd AllerWise
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Configure Firebase:

   - Add your `google-services.json` file to `android/app/`
   - Add your `GoogleService-Info.plist` file to `ios/Runner/`

4. Configure OpenAI API:
   - Open `lib/core/config/app_config.dart`
   - Replace `YOUR_OPENAI_API_KEY_HERE` with your actual OpenAI API key:
     ```dart
     static const String _apiKey = 'sk-proj-your-actual-api-key-here';
     ```

### Assets

The app includes the following assets:

- **Character Sprites**: `assets/images/characters/waiter_spritesheet.png` and `waiter_talking_spritesheet.png`
- **Backgrounds**: `assets/images/backgrounds/restaurant_interior.png`
- **Audio**: `assets/audio/` (for ambient sounds)

### Running the App

1. Ensure you have configured Firebase and OpenAI API key
2. Run the app:
   ```bash
   flutter run
   ```

## AI Conversation System

### Architecture

The AI conversation system consists of several key components:

1. **OpenAI Dialogue Service** (`lib/services/openai_dialogue_service.dart`)

   - Handles GPT-3.5 Turbo API calls
   - Manages conversation context and history
   - Provides realistic restaurant waiter persona

2. **Realistic TTS Service** (`lib/services/realistic_tts_service.dart`)

   - Uses OpenAI's neural TTS for human-like speech
   - Fallback to flutter_tts for reliability
   - Supports multiple voice options

3. **AI Conversation Controller** (`lib/views/integrated_conversation/ai_conversation_controller.dart`)

   - Coordinates between dialogue service and UI
   - Manages conversation state and flow
   - Handles user input and AI responses

4. **Interactive Waiter Game** (`lib/views/integrated_conversation/interactive_waiter_game.dart`)
   - Flame game engine integration
   - Character animation synchronization
   - Background management

### Usage

1. Launch the app and navigate to the home screen
2. Tap the "AI" button in the bottom navigation
3. The AI conversation screen will open with a virtual waiter
4. Start talking about your dining preferences and allergies
5. The AI will respond with realistic restaurant interactions

### Models

- **GameState**: Tracks user progress and confidence levels
- **SimulationStep**: Defines conversation scenarios
- **PlayerProfile**: Stores user allergies and preferences

## Security Notes

- **API Keys**: Never commit API keys to version control
- **Environment Variables**: Consider using environment variables for production
- **Error Handling**: The app includes comprehensive error handling for API failures

## Development

### File Structure

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart        # Configuration and API keys
│   ├── constants.dart             # App constants
│   └── theme/                     # App themes
├── controllers/                   # Riverpod controllers
├── models/                        # Data models
│   ├── game_state.dart
│   ├── simulation_step.dart
│   └── user_model.dart
├── services/                      # API services
│   ├── openai_dialogue_service.dart
│   ├── realistic_tts_service.dart
│   └── auth_service.dart
├── views/
│   ├── integrated_conversation/   # AI conversation screens
│   ├── components/                # Game components
│   ├── auth/                      # Authentication screens
│   └── home/                      # Home screen
└── main.dart                      # App entry point
```

### Dependencies

Key dependencies include:

- `flame`: Game engine for character animation
- `provider`: State management
- `speech_to_text`: Speech recognition
- `flutter_tts`: Text-to-speech fallback
- `http`: API communications
- `path_provider`: File system access
- `audioplayers`: Audio playback

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions, please create an issue on the GitHub repository.
