// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

using CuttingEdge.ManagerPortal.Models;
using CuttingEdge.ManagerPortal.Services;
using CuttingEdge.ManagerPortal.ViewModels;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class GalleryController : Controller
{
    private readonly SupabaseService _supabaseService;

    public GalleryController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Gallery
    public async Task<IActionResult> Index()
    {
        try
        {
            var images = await _supabaseService.GetAllGalleryImagesAsync();
            var aboutUs = await _supabaseService.GetAboutUsContentAsync();

            var viewModel = new GalleryViewModel
            {
                Images = images,
                AboutUs = aboutUs
            };

            return View(viewModel);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading gallery: {ex.Message}";
            return View(new GalleryViewModel());
        }
    }

    // POST: /Gallery/Upload
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Upload(IFormFile file, string title, string? description)
    {
        if (file == null || file.Length == 0)
        {
            TempData["Error"] = "Please select a file to upload.";
            return RedirectToAction(nameof(Index));
        }

        try
        {
            await _supabaseService.UploadGalleryImageAsync(file, title, description);
            TempData["Success"] = "Image uploaded successfully.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Upload failed: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }

    // POST: /Gallery/Edit/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, string title, string? description)
    {
        try
        {
            await _supabaseService.UpdateGalleryImageAsync(id, title, description);
            TempData["Success"] = "Image updated.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }

    // POST: /Gallery/Delete/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(long id)
    {
        try
        {
            await _supabaseService.DeleteGalleryImageAsync(id);
            TempData["Success"] = "Image deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Delete failed: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }

    // POST: /Gallery/UpdateAboutUs
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateAboutUs(string aboutUs)
    {
        try
        {
            await _supabaseService.UpdateAboutUsAsync(aboutUs);
            TempData["Success"] = "About Us updated.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}