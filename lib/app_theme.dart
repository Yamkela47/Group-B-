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

import 'package:flutter/material.dart';

/// The `AppColors` class is a central place to store all the color constants
/// used throughout the application. This ensures that the color scheme stays
/// consistent and makes it easy to change colors globally if needed.
class AppColors {
  static const Color gold       = Color(0xFFE8C158); // The primary brand color
  static const Color goldDim    = Color(0xFFB8942F); // A darker gold for subtle accents
  static const Color black      = Color(0xFF000000); // Pure black for backgrounds
  static const Color surface    = Color(0xFF101010); // Very dark grey for main surfaces
  static const Color surfaceAlt = Color(0xFF171717); // Slightly lighter dark grey for cards/alt surfaces
  static const Color border     = Color(0xFF2A2A2A); // Dark grey for borders to separate UI elements
  static const Color textPrimary   = Color(0xFFFFFFFF); // White text for primary readability
  static const Color textSecondary = Color(0xFF9E9E9E); // Light grey text for secondary information
  static const Color textMuted     = Color(0xFF6B6B6B); // Darker grey text for hints or disabled states
  static const Color error      = Color(0xFFE5484D); // Red color for errors and destructive actions
  static const Color success    = Color(0xFF3DD68C); // Green color for success messages
}

/// The `AppTheme` class defines the overall visual appearance of the app.
/// It uses a getter `dark` to return a pre-configured `ThemeData` object
/// that implements the specific dark/gold aesthetic of Cutting Edge Salon.
class AppTheme {
  static ThemeData get dark => ThemeData(
        // Sets the overall theme to dark mode
        brightness: Brightness.dark,
        // Sets the background color of Scaffold widgets to pure black
        scaffoldBackgroundColor: AppColors.black,
        // Sets the primary accent color to gold
        primaryColor: AppColors.gold,
        // Defines the color of the splash effect when tapping elements (semi-transparent gold)
        splashColor: AppColors.gold.withValues(alpha: 0.08),
        // Defines the color of the highlight effect (semi-transparent gold)
        highlightColor: AppColors.gold.withValues(alpha: 0.04),
        
        // Custom ColorScheme mapping specific UI elements to our colors
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.gold,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: Colors.black, // Text/icon color on top of primary (gold) elements
          onSurface: Colors.white, // Text/icon color on top of surface elements
        ),
        
        // Uses the default Roboto font
        fontFamily: 'Roboto',
        
        // Customizes the appearance of AppBars across the entire app
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.black,
          elevation: 0, // Removes the drop shadow
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white), // Default icon color
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        
        // Customizes the appearance of TextFields and TextFormFields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceAlt, // Background color of the input field
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          
          // Default border style (when not focused)
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), // Rounded corners
            borderSide: const BorderSide(color: AppColors.border),
          ),
          
          // Border style when enabled but not focused
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          
          // Border style when the user is typing in the field
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.4), // Gold border on focus
          ),
        ),
        
        // Customizes the appearance of ElevatedButtons (the solid buttons)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold, // Gold background
            foregroundColor: Colors.black, // Black text
            minimumSize: const Size.fromHeight(52), // Makes the button full-width and tall
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            elevation: 0, // Removes the default 3D shadow effect
          ),
        ),
        
        // Customizes the appearance of OutlinedButtons (transparent with a border)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold, // Gold text
            side: const BorderSide(color: AppColors.gold, width: 1.2), // Gold border
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
        ),
        
        // Customizes the appearance of TextButtons (just text, no background or border)
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
        ),
        
        // Customizes the appearance of Divider lines
        dividerTheme: const DividerThemeData(
          color: AppColors.border, 
          thickness: 1, 
          space: 1,
        ),
      );
}