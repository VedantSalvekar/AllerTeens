# Codemagic Setup Guide for AllerWise

This guide will help you set up Codemagic CI/CD for building your Flutter app for both Android and iOS platforms.

## Prerequisites

- [x] Flutter app connected to Codemagic via GitHub
- [x] Firebase project configured with Android and iOS apps
- [x] Google Play Console account (for Android)
- [x] Apple Developer account (for iOS)

## 1. Environment Variables Setup

### In Codemagic Dashboard:

1. Go to your app settings → Environment variables
2. Create a new group called `firebase`
3. Add the following variables:

#### For Android:

```
ANDROID_KEYSTORE_ALIAS=your_key_alias
ANDROID_KEYSTORE_PASSWORD=your_keystore_password
ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD=your_private_key_password
GCLOUD_SERVICE_ACCOUNT_CREDENTIALS=your_google_play_service_account_json
```

#### For iOS:

```
APP_STORE_CONNECT_ISSUER_ID=your_issuer_id
APP_STORE_CONNECT_KEY_IDENTIFIER=your_key_identifier
APP_STORE_CONNECT_PRIVATE_KEY=your_private_key
```

#### For Firebase (if using environment-specific configs):

```
FIREBASE_CONFIG_ANDROID=your_google_services_json_content
FIREBASE_CONFIG_IOS=your_firebase_plist_content
```

## 2. Android Setup

### 2.1 Generate Android Keystore

1. Generate a keystore file locally:

```bash
keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your_key_alias
```

2. Upload the keystore file to Codemagic:
   - Go to Code signing → Android keystores
   - Upload your `keystore.jks` file
   - Reference it as `keystore_reference` in your codemagic.yaml

### 2.2 Google Play Console Setup

1. Create a service account in Google Cloud Console
2. Download the JSON key file
3. In Google Play Console → Setup → API access → Link the service account
4. Grant necessary permissions (Release to testing tracks, Manage store presence)
5. Add the JSON content to `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` environment variable

## 3. iOS Setup

### 3.1 App Store Connect Integration

1. In Codemagic, go to Teams → Integrations
2. Add App Store Connect integration
3. Generate an App Store Connect API key:
   - Go to App Store Connect → Users and Access → Keys
   - Create a new key with App Manager role
   - Download the .p8 file
4. Add the key details to your environment variables

### 3.2 Code Signing Setup

1. In Codemagic, go to Code signing → iOS certificates
2. Upload your:
   - Distribution certificate (.p12 file)
   - Provisioning profile (.mobileprovision file)
3. Or use automatic code signing (recommended for App Store builds)

## 4. Update Your Configuration

### 4.1 Update Email Addresses

In your `codemagic.yaml`, replace `YOUR_EMAIL@example.com` with your actual email address for build notifications.

### 4.2 Verify Bundle Identifiers

Ensure your bundle identifiers match:

- Android: `com.allerwise.app.allerwise` (in `android/app/build.gradle.kts`)
- iOS: `com.allerwise.app.allerwise` (in iOS project settings)

## 5. Test Your Setup

### 5.1 Commit and Push Changes

```bash
git add .
git commit -m "Add Codemagic configuration"
git push origin main
```

### 5.2 Monitor Build Status

1. Go to Codemagic dashboard
2. Check if builds are triggered automatically
3. Monitor the build logs for any errors

## 6. Common Issues and Solutions

### Android Issues:

1. **Keystore not found**: Ensure keystore is uploaded and referenced correctly
2. **Google Play API errors**: Check service account permissions
3. **Firebase errors**: Verify `google-services.json` is present and valid

### iOS Issues:

1. **Code signing errors**: Ensure certificates and provisioning profiles are valid
2. **App Store Connect errors**: Check API key permissions
3. **Missing pods**: Ensure Podfile.lock is committed to Git

## 7. Advanced Configuration

### 7.1 Build Triggers

Current configuration triggers builds on:

- Push to main branch
- Pull requests
- Tags

### 7.2 Artifact Management

- Android: Builds AAB files for Google Play
- iOS: Creates IPA files for App Store

### 7.3 Distribution

- Android: Uploads to Google Play internal track
- iOS: Uploads to TestFlight

## 8. Next Steps

1. **Set up different environments**: Create staging and production workflows
2. **Add automated testing**: Expand test coverage
3. **Set up notifications**: Configure Slack/Teams integration
4. **Monitor performance**: Set up build time alerts

## Support

For issues specific to your setup:

1. Check Codemagic build logs
2. Review this guide
3. Consult Codemagic documentation: https://docs.codemagic.io/
4. Check Flutter documentation: https://flutter.dev/docs

---

**Note**: Keep your signing credentials secure and never commit them to version control.
