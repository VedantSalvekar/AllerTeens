// App configuration constants and settings
class AppConfig {
  // App configuration will be added here
  static const String appName = 'AllerWise';
  static const String appVersion = '1.0.0';
}

/// OpenAI API Configuration
class OpenAIConfig {
  // TODO: Move this to environment variables or secure storage
  // For development only - DO NOT commit real API keys to version control
  static const String _apiKey =
      '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';

  static String get apiKey {
    if (_apiKey == 'YOUR_OPENAI_API_KEY_HERE') {
      throw Exception(
        'OpenAI API key not configured. Please set the API key in lib/core/config/app_config.dart',
      );
    }
    return _apiKey;
  }

  static const String textToSpeechUrl =
      'https://api.openai.com/v1/audio/speech';
  static const String chatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';
}
