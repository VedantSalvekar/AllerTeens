# AllerTeens

A mobile app built with Flutter that helps teenagers learn how to safely navigate food allergies through AI-powered conversations.

## Key Features

- **AI Training Conversations** - Practice talking to a virtual waiter about your allergies
- **Product Scanning** - Scan barcodes to check for allergens in food products
- **Symptom Tracking** - Log allergy symptoms and track patterns over time
- **Adrenaline Pen Reminders** - Get notifications to check and maintain your emergency medication
- **Learning Modules** - Educational content about allergy management and safety
- **Progress Tracking** - See how your confidence and skills improve over time

## Getting Started

### What you need

- Flutter SDK (version 3.8.1 or higher)
- A Firebase project with Authentication and Firestore
- An OpenAI API key

### Setup

1. Clone this repository and install dependencies:

   ```bash
   git clone <repository-url>
   cd allerteens
   flutter pub get
   ```

2. Add Firebase configuration files:

   - Put your `google-services.json` in `android/app/`
   - Put your `GoogleService-Info.plist` in `ios/Runner/`

3. Add your OpenAI API key:

   - Open `lib/core/config/app_config.dart`
   - Replace the placeholder with your actual API key

4. Run the app:

   ```bash
   flutter run
   ```

## How it works

This is a complete allergy management toolkit for teenagers. The main feature is AI-powered simulations where you practice discussing allergies with a virtual ai character. Beyond training, you can scan products for allergens, track symptoms, set medication reminders, and access educational resources to build real-world confidence and safety skills.
