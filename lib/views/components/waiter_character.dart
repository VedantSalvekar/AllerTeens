import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame/flame.dart';

class WaiterCharacter extends SpriteAnimationComponent {
  final Function(String)? onAnimationComplete;
  late Vector2 initialPosition;

  // Animation states
  bool isWalking = false;
  bool isIdle = true;
  bool isTalking = false;

  // Store different sprite animations - now supporting dual spritesheets
  // Non-talking animations (mouth closed)
  late SpriteAnimation idleAnimation;
  late SpriteAnimation idlePositiveAnimation;
  late SpriteAnimation idleNegativeAnimation;
  late SpriteAnimation waitingAnimation; // Static animation for processing

  // Talking animations (mouth moving)
  late SpriteAnimation talkingAnimation;
  late SpriteAnimation talkingPositiveAnimation;
  late SpriteAnimation talkingNegativeAnimation;

  WaiterCharacter({required Vector2 position, this.onAnimationComplete})
    : super(position: position) {
    initialPosition = position.clone();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Set character size - dynamically sized to fill screen
    _setSizeBasedOnScreen();

    debugPrint(
      'WaiterCharacter: Loading at position $position with size $size',
    );

    // Load the waiter spritesheet
    await _loadWaiterAnimations();

    // Start with idle animation
    playIdleAnimation();

    // Ensure consistent positioning from the start
    _maintainConsistentPositioning();
  }

  Future<void> _loadWaiterAnimations() async {
    try {
      // Load both spritesheets
      final idleSpriteSheet = await Flame.images.load(
        'characters/waiter_spritesheet.png', // Non-talking spritesheet (mouth closed)
      );

      final talkingSpriteSheet = await Flame.images.load(
        'characters/waiter_talking_spritesheet.png', // Talking spritesheet (mouth moving)
      );

      debugPrint(
        'WaiterCharacter: Loaded idle spritesheet ${idleSpriteSheet.width}x${idleSpriteSheet.height}',
      );
      debugPrint(
        'WaiterCharacter: Loaded talking spritesheet ${talkingSpriteSheet.width}x${talkingSpriteSheet.height}',
      );

      // Ensure both spritesheets have the same dimensions for consistent positioning
      if (idleSpriteSheet.width != talkingSpriteSheet.width ||
          idleSpriteSheet.height != talkingSpriteSheet.height) {
        debugPrint(
          'WARNING: Spritesheets have different dimensions! This may cause positioning issues.',
        );
        debugPrint('Idle: ${idleSpriteSheet.width}x${idleSpriteSheet.height}');
        debugPrint(
          'Talking: ${talkingSpriteSheet.width}x${talkingSpriteSheet.height}',
        );
      }

      // Create animations from idle spritesheet (mouth closed)
      // Assuming both spritesheets have 4 columns and 3 rows (adjust as needed)

      // IDLE SPRITESHEET ANIMATIONS (mouth closed)

      // Row 1: Idle expressions (frames 0-3) - Very slow, subtle breathing
      idleAnimation = SpriteAnimation.fromFrameData(
        idleSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime:
              2.0, // Much slower - 2 seconds per frame for subtle breathing
          textureSize: Vector2(
            idleSpriteSheet.width / 4,
            idleSpriteSheet.height / 3,
          ),
          texturePosition: Vector2(0, 0), // First row
        ),
      );

      // Row 2: Positive reaction (mouth closed) - frames 4-7
      idlePositiveAnimation = SpriteAnimation.fromFrameData(
        idleSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.3,
          textureSize: Vector2(
            idleSpriteSheet.width / 4,
            idleSpriteSheet.height / 3,
          ),
          texturePosition: Vector2(0, idleSpriteSheet.height / 3), // Second row
        ),
      );

      // Row 3: Negative reaction (mouth closed) - frames 8-11
      idleNegativeAnimation = SpriteAnimation.fromFrameData(
        idleSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.3,
          textureSize: Vector2(
            idleSpriteSheet.width / 4,
            idleSpriteSheet.height / 3,
          ),
          texturePosition: Vector2(
            0,
            (idleSpriteSheet.height / 3) * 2,
          ), // Third row
        ),
      );

      // Static waiting animation - uses first frame of idle, no movement
      waitingAnimation = SpriteAnimation.fromFrameData(
        idleSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 1, // Only 1 frame for static appearance
          stepTime: 1.0, // Doesn't matter since it's static
          textureSize: Vector2(
            idleSpriteSheet.width / 4,
            idleSpriteSheet.height / 3,
          ),
          texturePosition: Vector2(0, 0), // First frame of idle row
        ),
      );

      // TALKING SPRITESHEET ANIMATIONS (mouth moving)

      // Row 1: Talking expressions (frames 0-3) - Mouth movement for speech
      talkingAnimation = SpriteAnimation.fromFrameData(
        talkingSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.4, // Slower for more natural mouth movement during speech
          textureSize: Vector2(
            talkingSpriteSheet.width / 4,
            talkingSpriteSheet.height / 3,
          ),
          texturePosition: Vector2(0, 0), // First row
        ),
      );

      // Row 2: Positive reaction while talking (frames 4-7) - Mouth moving + positive expression
      talkingPositiveAnimation = SpriteAnimation.fromFrameData(
        talkingSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.4, // Slower for more natural animation
          textureSize: Vector2(
            talkingSpriteSheet.width / 4,
            talkingSpriteSheet.height / 3,
          ),
          texturePosition: Vector2(
            0,
            talkingSpriteSheet.height / 3,
          ), // Second row
        ),
      );

      // Row 3: Negative reaction while talking (frames 8-11) - Mouth moving + negative expression
      talkingNegativeAnimation = SpriteAnimation.fromFrameData(
        talkingSpriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.4, // Slower for more natural animation
          textureSize: Vector2(
            talkingSpriteSheet.width / 4,
            talkingSpriteSheet.height / 3,
          ),
          texturePosition: Vector2(
            0,
            (talkingSpriteSheet.height / 3) * 2,
          ), // Third row
        ),
      );

      debugPrint(
        'WaiterCharacter: Successfully created all animations from dual spritesheets',
      );
    } catch (e) {
      // Fallback: use a single sprite if spritesheet loading fails
      debugPrint('Could not load waiter spritesheets: $e');
      // Create simple animation with single frame
      final fallbackSprite = await Sprite.load(
        'characters/waiter_spritesheet.png',
      );
      final fallbackAnimation = SpriteAnimation.spriteList([
        fallbackSprite,
      ], stepTime: 1.0);

      // Set all animations to the same fallback
      idleAnimation = fallbackAnimation;
      idlePositiveAnimation = fallbackAnimation;
      idleNegativeAnimation = fallbackAnimation;
      waitingAnimation = fallbackAnimation;
      talkingAnimation = fallbackAnimation;
      talkingPositiveAnimation = fallbackAnimation;
      talkingNegativeAnimation = fallbackAnimation;
    }
  }

  void playIdleAnimation() {
    isIdle = true;
    isWalking = false;
    isTalking = false;

    // Set the idle animation
    animation = idleAnimation;
  }

  Future<void> walkToPosition(Vector2 targetPosition) async {
    isWalking = true;
    isIdle = false;

    // Remove any existing effects
    removeAll(children.whereType<Effect>());

    // Create walking animation effect
    final moveEffect = MoveEffect.to(
      targetPosition,
      EffectController(duration: 1.5, curve: Curves.easeInOut),
    );

    add(moveEffect);

    // Wait for movement to complete
    await Future.delayed(const Duration(milliseconds: 1500));

    isWalking = false;
    playIdleAnimation();
  }

  Future<void> playGreetingAnimation() async {
    isTalking = true;
    isIdle = false;

    // Set talking animation
    animation = talkingAnimation;

    await Future.delayed(const Duration(milliseconds: 600));

    isTalking = false;
    onAnimationComplete?.call('greeting');
    playIdleAnimation();
  }

  void playPositiveReaction() {
    // Use appropriate positive animation based on talking state
    if (isTalking) {
      animation = talkingPositiveAnimation;
    } else {
      animation = idlePositiveAnimation;
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (isTalking) {
        // Return to talking animation if still talking
        animation = talkingAnimation;
      } else {
        // Return to idle if not talking
        playIdleAnimation();
      }
    });
  }

  void playNegativeReaction() {
    // Use appropriate negative animation based on talking state
    if (isTalking) {
      animation = talkingNegativeAnimation;
    } else {
      animation = idleNegativeAnimation;
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (isTalking) {
        // Return to talking animation if still talking
        animation = talkingAnimation;
      } else {
        // Return to idle if not talking
        playIdleAnimation();
      }
    });
  }

  void playWaitingAnimation() {
    // Set to static waiting animation (no movement)
    isIdle = false;
    isWalking = false;
    isTalking = false;

    animation = waitingAnimation;
  }

  /// Start talking animation - use this when AI begins speaking
  void startTalkingAnimation() {
    debugPrint('WaiterCharacter: Starting talking animation');
    isTalking = true;
    isIdle = false;
    isWalking = false;

    // Store current position and scale to maintain consistency
    final currentPos = position.clone();
    final currentScale = scale.clone();

    // Set the talking animation (mouth moving)
    animation = talkingAnimation;

    // Ensure position and scale remain consistent
    position = currentPos;
    scale = currentScale;
    _maintainConsistentPositioning();
  }

  /// Stop talking animation - use this when AI finishes speaking
  void stopTalkingAnimation() {
    debugPrint('WaiterCharacter: Stopping talking animation');
    isTalking = false;

    // Store current position and scale to maintain consistency
    final currentPos = position.clone();
    final currentScale = scale.clone();

    // Return to idle animation (mouth closed)
    playIdleAnimation();

    // Ensure position and scale remain consistent
    position = currentPos;
    scale = currentScale;
    _maintainConsistentPositioning();
  }

  /// Check if the character is currently in a talking state
  bool get isCurrentlyTalking => isTalking;

  /// Helper method to maintain consistent positioning across spritesheet changes
  void _maintainConsistentPositioning() {
    // Ensure the anchor point is always center for both spritesheets
    anchor = Anchor.center;

    // Only log occasionally for debugging (reduce spam)
    if (DateTime.now().millisecondsSinceEpoch % 1000 < 100) {
      debugPrint(
        'WaiterCharacter: Position maintained at $position, Scale: $scale',
      );
    }
  }

  /// Set character size based on screen dimensions to fill screen and touch edges
  void _setSizeBasedOnScreen() {
    // Get the parent game size
    final gameSize = findGame()?.size ?? Vector2(800, 600);

    // Set size to fill most of the screen width and proper height to show body
    final targetWidth =
        gameSize.x * 0.95; // 80% of screen width for better proportions
    final targetHeight =
        gameSize.y * 0.95; // 55% of screen height to show body properly

    final newSize = Vector2(targetWidth, targetHeight);

    // Only log and update if size actually changed
    if (size != newSize) {
      size = newSize;
      debugPrint(
        'WaiterCharacter: Size set to ${size.x}x${size.y} based on screen ${gameSize.x}x${gameSize.y}',
      );
    }
  }

  void resetToInitialState() {
    position = initialPosition.clone();
    isTalking = false;
    playIdleAnimation();
  }

  /// Handle game resize to maintain proper character sizing
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    // Store previous position and size to check for actual changes
    final previousPosition = position.clone();
    final previousSize = this.size.clone();

    _setSizeBasedOnScreen();

    // Update initial position based on new screen size
    final newInitialPosition = Vector2(size.x * 0.5, size.y * 0.55);

    // Only update and log if position actually changed
    if (initialPosition != newInitialPosition || this.size != previousSize) {
      initialPosition = newInitialPosition;
      position = initialPosition.clone();

      debugPrint('WaiterCharacter: Resized for screen ${size.x}x${size.y}');
    }
  }
}
