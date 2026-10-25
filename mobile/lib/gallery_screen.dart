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

import 'catalog_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'app_theme.dart';       // Custom colors and styles
import 'app_bars.dart';        // Custom AppBar widget

/// A screen that displays a gallery of hairstyle images.
/// It fetches images from Supabase, displays them in a grid, 
/// allows the user to view them full-screen, and download/share them.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _supabase = Supabase.instance.client;
  
  // State variables
  bool _loading = true;
  List<Map<String, dynamic>> _images = [];

  @override
  void initState() {
    super.initState();
    // Fetch the images as soon as the screen loads
    _fetchImages();
  }

  /// Fetches the list of gallery images from the 'gallery_images' table in Supabase.
  Future<void> _fetchImages() async {
    try {
      final data = await _supabase
          .from('gallery_images')
          .select('*')
          .order('created_at', ascending: false); // Newest images first

      if (!mounted) return;
      setState(() {
        _images = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Error loading gallery: $e');
    }
  }

  /// Downloads an image to a temporary file, then opens the device's native 
  /// Share/Save sheet so the user can save it to their phone's gallery.
  Future<void> _downloadImage(String imageUrl) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing image...'),
          backgroundColor: AppColors.gold,
        ),
      );

      // 1. Download the image bytes via HTTP
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Could not download image (${response.statusCode})');
      }

      // 2. Determine the file extension based on the content type
      final contentType = response.headers['content-type'] ?? '';
      final extension = contentType.contains('png')
          ? 'png'
          : contentType.contains('webp')
              ? 'webp'
              : 'jpg';
              
      // 3. Save the bytes to a temporary file on the device
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/cutting_edge_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;
      
      // 4. Trigger the native Share/Download dialog
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Cutting Edge Salon Gallery',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Gallery'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _images.isEmpty
              ? const Center(
                  child: Text(
                    'No images in the gallery yet.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.surfaceAlt,
                  onRefresh: _fetchImages,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 images per row
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      // Made the aspect ratio 1.0 so the boxes are perfect squares
                      childAspectRatio: 1.0, 
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final img = _images[index];
                      final String imageUrl = CatalogImage.resolve(img['image_url']?.toString()) ?? '';
                      final String title = img['title'] ?? 'Hairstyle';

                      if (imageUrl.isEmpty) return const SizedBox.shrink();

                      return GestureDetector(
                        onTap: () => _showFullScreenImage(context, imageUrl, title),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // The Image itself
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover, // Covers the whole square
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.surface,
                                    child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                                  ),
                                ),
                                // A gradient overlay at the bottom to make the text readable
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.9),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  /// Opens a full-screen dialog to view the selected image.
  void _showFullScreenImage(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16), // Keeps it from touching the edges
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The image is constrained to 80% of the screen height and allows pinching to zoom
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            
            // Close button at the top right
            Positioned(
              top: -10, right: -10,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: AppColors.gold, size: 36),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),

            // Download button at the bottom
            Positioned(
              bottom: 10,
              child: ElevatedButton.icon(
                onPressed: () => _downloadImage(imageUrl),
                icon: const Icon(Icons.download, size: 20),
                label: const Text('DOWNLOAD IMAGE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}