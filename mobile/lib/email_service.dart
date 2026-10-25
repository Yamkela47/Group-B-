/*
===========================================================
PROJECT: Cutting Edge Salon
STUDENT DETAILS:
-----------------------------------------------------------
Name                  | Student Number
-----------------------------------------------------------
Goitse Kgwele         | 221050663
Thabang Zitha         | 223007074
Yamkela Mazamani      | 224007421
Nyakallo Pali         | 223060226
Bennet Linda          | 224004294
===========================================================
*/

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart'; // Used to check if the app is running on the web (kIsWeb)

/// A service class responsible for sending emails to users.
/// It uses the `mailer` package to connect directly to an SMTP server (Gmail).
/// This is used for sending account verification codes and password reset codes.
class EmailService {
  // =================================================================
  // GMAIL CREDENTIALS
  // =================================================================
  // The sender's email address
  static const String smtpUser = 'frameworkfanatic@gmail.com';
  
  // Your 16-letter Google App Password (No spaces)
  static const String smtpPass = 'oaxnglcofclybkjl'; 

  // =================================================================
  // 1. SEND ACCOUNT VERIFICATION CODE
  // =================================================================
  /// Sends a 6-digit verification code to the user's email address.
  /// Returns `true` if the email was sent successfully, `false` otherwise.
  static Future<bool> sendVerificationCode(String recipientEmail, String code) async {
    // Configure the SMTP server for Gmail
    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 587,
      username: smtpUser,
      password: smtpPass,
      ssl: false, 
      allowInsecure: true,
    );

    // Construct the email message with HTML formatting
    final message = Message()
      ..from = Address(smtpUser, 'Cutting Edge Salon')
      ..recipients.add(recipientEmail)
      ..subject = 'Your Cutting Edge Verification Code'
      ..html = '''
        <div style="font-family: Arial, sans-serif; text-align: center; padding: 30px; background-color: #000000; color: #ffffff; border-radius: 10px;">
          <h2 style="color: #E8C158; margin-bottom: 20px;">Welcome to Cutting Edge</h2>
          <p style="font-size: 16px;">Your verification code is:</p>
          <h1 style="color: #E8C158; font-size: 48px; letter-spacing: 8px; margin: 20px 0;">$code</h1>
          <p style="font-size: 14px; color: #9E9E9E;">Please enter this code in the app to verify your account.</p>
          <hr style="border-color: #2A2A2A; margin-top: 30px;">
          <p style="font-size: 12px; color: #6B6B6B;">If you did not request this code, please ignore this email.</p>
        </div>
      ''';

    // Pass the message to the core sending function
    return _sendEmail(message, smtpServer, recipientEmail, 'Verification Code');
  }

  // =================================================================
  // 2. SEND PASSWORD RESET CODE
  // =================================================================
  /// Sends a password reset code to the user's email address.
  /// Returns `true` if the email was sent successfully, `false` otherwise.
  static Future<bool> sendPasswordResetCode(String recipientEmail, String code) async {
    // Configure the SMTP server for Gmail
    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 587,
      username: smtpUser,
      password: smtpPass,
      ssl: false, 
      allowInsecure: true,
    );

    // Construct the email message with HTML formatting
    final message = Message()
      ..from = Address(smtpUser, 'Cutting Edge Salon')
      ..recipients.add(recipientEmail)
      ..subject = 'Password Reset Code'
      ..html = '''
        <div style="font-family: Arial, sans-serif; text-align: center; padding: 30px; background-color: #000000; color: #ffffff; border-radius: 10px;">
          <h2 style="color: #E8C158; margin-bottom: 20px;">Password Reset</h2>
          <p style="font-size: 16px;">Your password reset code is:</p>
          <h1 style="color: #E8C158; font-size: 48px; letter-spacing: 8px; margin: 20px 0;">$code</h1>
          <p style="font-size: 14px; color: #9E9E9E;">If you did not request a password reset, please ignore this email.</p>
        </div>
      ''';

    // Pass the message to the core sending function
    return _sendEmail(message, smtpServer, recipientEmail, 'Password Reset');
  }

  // =================================================================
  // 3. CORE SEND LOGIC (Handles the actual SMTP connection)
  // =================================================================
  /// Handles the actual transmission of the email.
  /// It includes error handling and web platform detection.
  static Future<bool> _sendEmail(Message message, SmtpServer smtpServer, String recipientEmail, String emailType) async {
    try {
      // The 'mailer' package relies on 'dart:io' which is not available on Flutter Web.
      // This guard prevents the app from crashing if it runs in a browser.
      if (kIsWeb) {
        debugPrint('WARNING: SMTP is not supported on Flutter Web (Chrome). Please run on an Android/iOS Emulator or Windows/Mac Desktop app.');
        return false;
      }

      // Attempt to send the email
      await send(message, smtpServer);
      debugPrint('SUCCESS: $emailType email sent successfully to $recipientEmail');
      return true;
      
    } catch (e) {
      // Catch and log any errors (e.g., network issues, wrong credentials)
      debugPrint('ERROR: Failed to send $emailType email: $e');
      return false;
    }
  }
}