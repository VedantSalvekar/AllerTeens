import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../components/waiter_character.dart';
import '../components/restaurant_background.dart';

/// Modified game component specifically for AI conversation interaction
/// This combines the visual elements of AllergyTrainingGame with AI conversation controls
class InteractiveWaiterGame extends FlameGame {
  WaiterCharacter? waiter;
  RestaurantBackground? background;

  // Game state
  bool gameReady = false;
  String currentAnimationState = 'idle';

  // Animation timing
  TimerComponent? _animationTimer;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Initialize camera
    camera.viewfinder.visibleGameSize = size;

    // Load and add background
    background = RestaurantBackground();
    background!.size = size;
    add(background!);

    // Load and add waiter character - positioned to show body while touching bottom
    waiter = WaiterCharacter(
      position: Vector2(
        size.x * 0.5,
        size.y * 0.7, // Higher position to show more of the body
      ), // Position to show waiter body properly
      onAnimationComplete: _onWaiterAnimationComplete,
    );

    waiter!.anchor = Anchor.center;
    add(waiter!);

    // Mark game as ready
    gameReady = true;
  }

  // Animation control methods called by AI conversation controller

  /// Called when AI starts greeting
  void onAIGreeting() {
    currentAnimationState = 'greeting';
    waiter?.playGreetingAnimation();
  }

  /// Called when AI is thinking/processing
  void onAIThinking() {
    currentAnimationState = 'thinking';
    // For thinking, use static waiting animation (no movement)
    waiter?.playWaitingAnimation();
  }

  /// Called when AI starts speaking (triggered by TTS start event)
  void onAIStartSpeaking() {
    currentAnimationState = 'talking';

    // Stop any existing loop first
    _stopTalkingLoop();

    // Start talking animation using new dual spritesheet method
    if (waiter != null) {
      waiter!.startTalkingAnimation();

      // Keep talking animation active with a loop
      _startTalkingLoop();
    }
  }

  /// Called when AI stops speaking (triggered by TTS completion event)
  void onAIStopSpeaking() {
    currentAnimationState = 'idle';

    // Stop talking loop immediately
    _stopTalkingLoop();

    // Stop talking animation using new dual spritesheet method
    if (waiter != null) {
      waiter!.stopTalkingAnimation();
    }
  }

  /// Called when AI gives positive feedback
  void onPositiveFeedback() {
    currentAnimationState = 'positive';
    waiter?.playPositiveReaction();

    // Return to idle after positive reaction
    Future.delayed(const Duration(milliseconds: 800), () {
      if (currentAnimationState == 'positive') {
        onAIStopSpeaking();
      }
    });
  }

  /// Called when AI gives negative/corrective feedback
  void onNegativeFeedback() {
    currentAnimationState = 'negative';
    waiter?.playNegativeReaction();

    // Return to idle after negative reaction
    Future.delayed(const Duration(milliseconds: 600), () {
      if (currentAnimationState == 'negative') {
        onAIStopSpeaking();
      }
    });
  }

  /// Starts the talking animation loop to keep it active while AI is speaking
  void _startTalkingLoop() {
    // Make sure we stop any existing loop first
    _stopTalkingLoop();

    // Only start if we're in talking state and have a waiter
    if (currentAnimationState != 'talking' || waiter == null) {
      return;
    }

    _animationTimer = TimerComponent(
      period: 0.2, // 200ms in seconds - slightly slower for better performance
      repeat: true,
      onTick: () {
        // Double check we're still in talking state and have waiter
        if (currentAnimationState == 'talking' &&
            waiter != null &&
            waiter!.isCurrentlyTalking) {
          // Keep the talking animation active using the new dual spritesheet system
          waiter!.animation = waiter!.talkingAnimation;
        } else {
          // Stop the loop if we're no longer talking
          _stopTalkingLoop();
        }
      },
    );

    if (gameReady && _animationTimer != null) {
      add(_animationTimer!);
    }
  }

  /// Stops the talking animation loop
  void _stopTalkingLoop() {
    if (_animationTimer != null) {
      try {
        _animationTimer!.removeFromParent();
      } catch (e) {
        debugPrint('Error removing animation timer: $e');
      }
      _animationTimer = null;
    }
  }

  /// Called when waiter animation completes
  void _onWaiterAnimationComplete(String animationName) {
    // Handle specific animation completions
    switch (animationName) {
      case 'greeting':
        // After greeting, return to idle
        if (currentAnimationState == 'greeting') {
          onAIStopSpeaking();
        }
        break;
      default:
        // For other animations, maintain current state
        break;
    }
  }

  /// Reset the game state
  void resetGame() {
    _stopTalkingLoop();
    currentAnimationState = 'idle';

    if (waiter != null) {
      waiter!.resetToInitialState();
    }
  }

  /// Update background if needed
  Future<void> updateBackground(String imagePath) async {
    if (background != null) {
      await background!.updateBackground(imagePath);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update waiter if initialized
    if (waiter != null) {
      waiter!.update(dt);
    }
  }

  @override
  void onRemove() {
    _stopTalkingLoop();
    super.onRemove();
  }
}
