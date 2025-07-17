import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

class RestaurantBackground extends SpriteComponent {
  String currentBackgroundPath = '';

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Load the restaurant background image
    await _loadRestaurantBackground();
  }

  Future<void> _loadRestaurantBackground() async {
    try {
      // Load the restaurant interior image
      sprite = await Sprite.load('backgrounds/restaurant_interior.png');

      // Make sure it covers the entire game area - will be set properly when added to game
      debugPrint('Successfully loaded restaurant background');
    } catch (e) {
      debugPrint('Could not load restaurant background: $e');
      // Don't use fallback rendering - let it be transparent so we can see what's wrong
      sprite = null;
    }
  }

  Future<void> updateBackground(String imagePath) async {
    if (currentBackgroundPath == imagePath) return;

    currentBackgroundPath = imagePath;

    // Load new background image
    try {
      sprite = await Sprite.load(imagePath);
      debugPrint('Updated background to: $imagePath');
    } catch (e) {
      // Fallback to default restaurant image
      debugPrint(
          'Could not load background $imagePath: $e, falling back to default');
      await _loadRestaurantBackground();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }
}
