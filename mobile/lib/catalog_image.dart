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
import 'package:supabase_flutter/supabase_flutter.dart';

/// A versatile image widget designed to load images primarily from Supabase Storage.
/// It features a built-in placeholder for errors or missing images and supports
/// circular clipping for profile pictures.
class CatalogImage extends StatelessWidget {
  final String? source;    // The file path or full URL of the image
  final double? width;     // Optional width constraint
  final double? height;    // Optional height constraint
  final BoxFit fit;        // How the image should fit into its box (default: cover)
  final bool circular;     // If true, the image will be clipped into a circle
  
  const CatalogImage({
    super.key, 
    this.source, 
    this.width, 
    this.height,
    this.fit = BoxFit.cover, 
    this.circular = false
  });

  /// A static helper method to resolve the image URL.
  /// 
  /// It handles different formats:
  /// 1. If it's already an HTTP/HTTPS link, it returns it as is.
  /// 2. If it starts with the bucket name ('catalog-images/'), it strips that prefix.
  /// 3. It then uses the Supabase client to generate a public URL for the file.
  static String? resolve(String? source) {
    var value = source?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('https://') || value.startsWith('http://')) return value;
    if (value.startsWith('catalog-images/')) {
      value = value.substring('catalog-images/'.length);
    }
    return Supabase.instance.client.storage.from('catalog-images').getPublicUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    // Attempt to resolve the final URL
    final url = resolve(source);
    
    // If the URL is null/empty, show the placeholder. 
    // Otherwise, load the network image, falling back to the placeholder on error.
    Widget child = url == null
        ? _placeholder()
        : Image.network(
            url, 
            width: width, 
            height: height, 
            fit: fit,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
          
    // If 'circular' is true, wrap the image in a ClipOval to make it perfectly round.
    if (circular) {
      child = ClipOval(
        child: SizedBox(
          width: width, 
          height: height, 
          child: child
        )
      );
    }
    
    return child;
  }

  /// A fallback UI widget shown when the image fails to load or is missing.
  /// It displays a dark grey box with a subtle gold image icon.
  Widget _placeholder() => Container(
    width: width, 
    height: height,
    alignment: Alignment.center, 
    color: const Color(0xFF242424), // Dark grey background
    child: const Icon(
      Icons.image_outlined, 
      color: Color(0xFFD4AF37) // Gold icon color
    ),
  );
}