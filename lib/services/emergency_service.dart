import 'package:url_launcher/url_launcher.dart';

/// Service for handling emergency contact functionality
class EmergencyService {
  /// Make a phone call to the emergency contact
  static Future<bool> callEmergencyContact(String phoneNumber) async {
    try {
      // Clean the phone number (remove spaces, dashes, parentheses)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Create the phone URL
      final phoneUrl = Uri.parse('tel:$cleanPhone');

      // Check if the URL can be launched
      if (await canLaunchUrl(phoneUrl)) {
        // Launch the phone call
        return await launchUrl(phoneUrl);
      } else {
        print('[EMERGENCY_SERVICE] Cannot launch phone call to: $phoneNumber');
        return false;
      }
    } catch (e) {
      print('[EMERGENCY_SERVICE] Error making phone call: $e');
      return false;
    }
  }

  /// Send an SMS to the emergency contact
  static Future<bool> sendEmergencySMS(
    String phoneNumber,
    String message,
  ) async {
    try {
      // Clean the phone number
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Create the SMS URL
      final smsUrl = Uri.parse(
        'sms:$cleanPhone?body=${Uri.encodeComponent(message)}',
      );

      // Check if the URL can be launched
      if (await canLaunchUrl(smsUrl)) {
        // Launch the SMS
        return await launchUrl(smsUrl);
      } else {
        print('[EMERGENCY_SERVICE] Cannot launch SMS to: $phoneNumber');
        return false;
      }
    } catch (e) {
      print('[EMERGENCY_SERVICE] Error sending SMS: $e');
      return false;
    }
  }

  /// Format phone number for display
  static String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Format based on length
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    } else {
      // Return as is if it doesn't match common patterns
      return phoneNumber;
    }
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Basic validation: should be 10-15 digits (with optional + prefix)
    final phoneRegex = RegExp(r'^[\+]?[1-9][\d]{9,14}$');
    return phoneRegex.hasMatch(cleanPhone);
  }
}
