import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/config/app_config.dart';

/// Service that provides realistic, human-like TTS using OpenAI's neural TTS API
/// with fallback to flutter_tts for reliability
class RealisticTTSService {
  static const String _ttsApiUrl = 'https://api.openai.com/v1/audio/speech';

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _fallbackTts = FlutterTts();

  // Voice options for variety
  // Male voices: echo, onyx, fable
  // Female voices: nova, shimmer, alloy
  static const List<String> _availableVoices = [
    'nova', // Female
    'echo', // Male (default)
    'shimmer', // Female
    'onyx', // Male
    'fable', // Male
    'alloy', // Female
  ];

  static const List<String> _maleVoices = ['echo', 'onyx', 'fable'];
  static const List<String> _femaleVoices = ['nova', 'shimmer', 'alloy'];

  String _currentVoice = 'echo'; // Default male voice
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentTempFilePath;

  // Animation synchronization callbacks
  Function()? onTTSStarted;
  Function()? onTTSCompleted;
  Function(String)? onError;

  RealisticTTSService() {
    // Set to male voice by default
    _currentVoice = 'echo'; // Ensure male voice is set
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize AudioPlayer with optimizations
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setBalance(0.0);
      await _audioPlayer.setVolume(1.0);

      // Log platform info for debugging
      debugPrint(
        'RealisticTTSService: Initializing on platform: ${Platform.operatingSystem}',
      );
      if (Platform.isIOS) {
        debugPrint(
          'RealisticTTSService: Running on iOS - performance may be affected by simulator',
        );
      }

      // Set up AudioPlayer callbacks
      _audioPlayer.onPlayerComplete.listen((_) {
        debugPrint('RealisticTTSService: Audio playback completed');
        _isPlaying = false;
        _cleanupTempFile();
        onTTSCompleted?.call();
      });

      _audioPlayer.onPlayerStateChanged.listen((state) {
        debugPrint('RealisticTTSService: Player state changed to $state');
        if (state == PlayerState.playing && !_isPlaying) {
          _isPlaying = true;

          // Add a longer delay before starting animation to ensure audio is actually audible
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_isPlaying) {
              // Double check we're still playing
              debugPrint(
                'RealisticTTSService: Audio confirmed playing, starting animation',
              );
              onTTSStarted?.call();
            }
          });
        }
      });

      // Initialize fallback TTS
      await _initializeFallbackTTS();

      _isInitialized = true;
      debugPrint('RealisticTTSService: Initialized successfully');
    } catch (e) {
      debugPrint('RealisticTTSService: Initialization error: $e');
      onError?.call('Failed to initialize TTS service');
    }
  }

  Future<void> _initializeFallbackTTS() async {
    try {
      await _fallbackTts.setLanguage('en-US');
      await _fallbackTts.setSpeechRate(0.5);
      await _fallbackTts.setPitch(1.0);
      await _fallbackTts.setVolume(1.0);

      // Set up fallback TTS callbacks
      _fallbackTts.setCompletionHandler(() {
        debugPrint('RealisticTTSService: Fallback TTS completed');
        _isPlaying = false;
        onTTSCompleted?.call();
      });

      _fallbackTts.setStartHandler(() {
        debugPrint('RealisticTTSService: Fallback TTS started');
        _isPlaying = true;

        // Add a longer delay for fallback TTS to ensure audio is actually audible
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_isPlaying) {
            // Double check we're still playing
            debugPrint(
              'RealisticTTSService: Fallback TTS confirmed playing, starting animation',
            );
            onTTSStarted?.call();
          }
        });
      });

      debugPrint('RealisticTTSService: Fallback TTS initialized');
    } catch (e) {
      debugPrint('RealisticTTSService: Fallback TTS initialization error: $e');
    }
  }

  /// Speak text using OpenAI's neural TTS with fallback to flutter_tts
  Future<void> speakWithNaturalVoice(
    String text, {
    String? voice,
    bool useHighQuality = true,
  }) async {
    if (!_isInitialized) {
      debugPrint('RealisticTTSService: Not initialized, using fallback');
      await _speakWithFallback(text);
      return;
    }

    if (text.trim().isEmpty) {
      debugPrint('RealisticTTSService: Empty text provided');
      return;
    }

    // Stop any current playback
    await stopSpeaking();

    try {
      // Check if API key is properly configured
      String apiKey;
      try {
        apiKey = OpenAIConfig.apiKey;
        debugPrint(
          'RealisticTTSService: Using OpenAI API key (first 10 chars): ${apiKey.substring(0, 10)}...',
        );
      } catch (e) {
        debugPrint('RealisticTTSService: API key error: $e');
        throw Exception('OpenAI API key not configured properly');
      }

      // Use OpenAI TTS API
      debugPrint(
        'RealisticTTSService: Attempting OpenAI TTS with voice: ${voice ?? _currentVoice}',
      );
      final audioData = await _generateSpeechFromOpenAI(
        text,
        voice: voice ?? _currentVoice,
        useHighQuality: useHighQuality,
      );

      if (audioData != null) {
        // Save to temp file and play
        debugPrint(
          'RealisticTTSService: Successfully generated audio data (${audioData.length} bytes), starting playback...',
        );
        await _playAudioData(audioData);
        debugPrint('RealisticTTSService: OpenAI TTS playback initiated');
      } else {
        throw Exception(
          'Failed to generate speech from OpenAI - no audio data returned',
        );
      }
    } catch (e) {
      debugPrint('RealisticTTSService: Error with OpenAI TTS: $e');
      onError?.call(
        'OpenAI TTS failed: ${e.toString()}. Using fallback voice.',
      );

      // Fallback to flutter_tts
      debugPrint('RealisticTTSService: Falling back to flutter_tts');
      await _speakWithFallback(text);
    }
  }

  /// Generate speech using OpenAI's TTS API
  Future<Uint8List?> _generateSpeechFromOpenAI(
    String text, {
    required String voice,
    required bool useHighQuality,
  }) async {
    try {
      debugPrint(
        'RealisticTTSService: Generating speech for: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
      );

      final response = await http
          .post(
            Uri.parse(_ttsApiUrl),
            headers: {
              'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': useHighQuality ? 'tts-1-hd' : 'tts-1',
              'input': text,
              'voice': voice,
              'response_format': 'mp3',
              'speed': 1.0,
            }),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw Exception(
                'TTS request timeout - please check your internet connection',
              );
            },
          );

      if (response.statusCode == 200) {
        debugPrint(
          'RealisticTTSService: Successfully generated speech from OpenAI',
        );
        return response.bodyBytes;
      } else {
        debugPrint(
          'RealisticTTSService: OpenAI API error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('RealisticTTSService: Network error calling OpenAI: $e');
      return null;
    }
  }

  /// Save audio data to temp file and play it
  Future<void> _playAudioData(Uint8List audioData) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFilePath =
          '${tempDir.path}/tts_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';

      // Save audio data to file
      final file = File(tempFilePath);
      await file.writeAsBytes(audioData);

      debugPrint('RealisticTTSService: Saved audio to: $tempFilePath');

      // Store current file path for cleanup
      _currentTempFilePath = tempFilePath;

      // Play the audio file
      debugPrint('RealisticTTSService: About to call _audioPlayer.play()');
      await _audioPlayer.play(DeviceFileSource(tempFilePath));

      debugPrint(
        'RealisticTTSService: _audioPlayer.play() completed - player state change should trigger soon',
      );
    } catch (e) {
      debugPrint('RealisticTTSService: Error playing audio: $e');
      _cleanupTempFile();
      throw e;
    }
  }

  /// Fallback to flutter_tts
  Future<void> _speakWithFallback(String text) async {
    try {
      debugPrint('RealisticTTSService: Using fallback TTS for: "$text"');
      await _fallbackTts.stop();

      final result = await _fallbackTts.speak(text);

      if (result != 1) {
        debugPrint('RealisticTTSService: Fallback TTS failed to start');
        onTTSCompleted?.call();
      }
    } catch (e) {
      debugPrint('RealisticTTSService: Fallback TTS error: $e');
      onError?.call('Failed to play speech');
      onTTSCompleted?.call();
    }
  }

  /// Clean up temporary audio file
  void _cleanupTempFile() {
    if (_currentTempFilePath != null) {
      try {
        final file = File(_currentTempFilePath!);
        if (file.existsSync()) {
          file.deleteSync();
          debugPrint(
            'RealisticTTSService: Cleaned up temp file: $_currentTempFilePath',
          );
        }
      } catch (e) {
        debugPrint('RealisticTTSService: Error cleaning up temp file: $e');
      }
      _currentTempFilePath = null;
    }
  }

  /// Stop current speech playback
  Future<void> stopSpeaking() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        await _fallbackTts.stop();
        _isPlaying = false;
        _cleanupTempFile();
        debugPrint('RealisticTTSService: Stopped speaking');
      }
    } catch (e) {
      debugPrint('RealisticTTSService: Error stopping speech: $e');
    }
  }

  /// Set the voice for future speech generation
  void setVoice(String voice) {
    if (_availableVoices.contains(voice)) {
      _currentVoice = voice;
      debugPrint('RealisticTTSService: Voice set to: $voice');
    } else {
      debugPrint(
        'RealisticTTSService: Invalid voice: $voice. Using default: $_currentVoice',
      );
    }
  }

  /// Get list of available voices
  List<String> getAvailableVoices() => List.from(_availableVoices);

  /// Get current voice
  String getCurrentVoice() => _currentVoice;

  /// Set voice to a male voice (default: echo)
  void setMaleVoice({String? preferredVoice}) {
    String voiceToUse = preferredVoice ?? 'echo';
    if (_maleVoices.contains(voiceToUse)) {
      _currentVoice = voiceToUse;
      debugPrint('RealisticTTSService: Male voice set to: $_currentVoice');
    } else {
      _currentVoice = 'echo'; // Default male voice
      debugPrint(
        'RealisticTTSService: Invalid male voice, using default: $_currentVoice',
      );
    }
  }

  /// Set voice to a female voice (default: nova)
  void setFemaleVoice({String? preferredVoice}) {
    String voiceToUse = preferredVoice ?? 'nova';
    if (_femaleVoices.contains(voiceToUse)) {
      _currentVoice = voiceToUse;
      debugPrint('RealisticTTSService: Female voice set to: $_currentVoice');
    } else {
      _currentVoice = 'nova'; // Default female voice
      debugPrint(
        'RealisticTTSService: Invalid female voice, using default: $_currentVoice',
      );
    }
  }

  /// Get available male voices
  List<String> getMaleVoices() => List.from(_maleVoices);

  /// Get available female voices
  List<String> getFemaleVoices() => List.from(_femaleVoices);

  /// Check if currently playing
  bool get isPlaying => _isPlaying;

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    _fallbackTts.stop();
    _cleanupTempFile();
    debugPrint('RealisticTTSService: Disposed');
  }
}
