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
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class PromotionsController : Controller
{
    private readonly SupabaseService _supabaseService;

    public PromotionsController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Promotions
    public async Task<IActionResult> Index()
    {
        try
        {
            var promotions = await _supabaseService.GetAllPromotionsAsync();
            return View(promotions);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading promotions: {ex.Message}";
            return View(new List<Promotion>());
        }
    }

    // GET: /Promotions/Create
    public async Task<IActionResult> Create()
    {
        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View();
    }

    // POST: /Promotions/Create
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Promotion promotion, IFormFile? imageFile)
    {
        if (ModelState.IsValid)
        {
            try
            {
                promotion.ImageUrl = null;
                if (imageFile != null && imageFile.Length > 0)
                    promotion.ImageUrl = await _supabaseService.UploadCatalogImageAsync(imageFile, "promotions");
                try { await _supabaseService.CreatePromotionAsync(promotion); }
                catch
                {
                    if (promotion.ImageUrl != null)
                        try { await _supabaseService.DeleteCatalogImageAsync(promotion.ImageUrl); } catch { }
                    throw;
                }
                TempData["Success"] = "Promotion created successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error creating promotion: {ex.Message}");
            }
        }

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(promotion);
    }

    // GET: /Promotions/Edit/{id}
    public async Task<IActionResult> Edit(long id)
    {
        var promotion = await _supabaseService.GetPromotionByIdAsync(id);
        if (promotion == null)
            return NotFound();

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(promotion);
    }

    // POST: /Promotions/Edit/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, Promotion promotion, IFormFile? imageFile, bool removeImage = false)
    {
        if (id != promotion.PromotionId)
            return NotFound();

        if (ModelState.IsValid)
        {
            try
            {
                var existing = await _supabaseService.GetPromotionByIdAsync(id);
                if (existing == null) return NotFound();
                promotion.ImageUrl = existing.ImageUrl;
                string? uploaded = null;
                if (imageFile != null && imageFile.Length > 0)
                    promotion.ImageUrl = uploaded = await _supabaseService.UploadCatalogImageAsync(imageFile, "promotions");
                else if (removeImage)
                    promotion.ImageUrl = null;
                try { await _supabaseService.UpdatePromotionAsync(promotion); }
                catch
                {
                    if (uploaded != null)
                        try { await _supabaseService.DeleteCatalogImageAsync(uploaded); } catch { }
                    throw;
                }
                if (existing.ImageUrl != promotion.ImageUrl)
                    try { await _supabaseService.DeleteCatalogImageAsync(existing.ImageUrl); } catch { }
                TempData["Success"] = "Promotion updated successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating promotion: {ex.Message}");
            }
        }

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(promotion);
    }

    // POST: /Promotions/Delete/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(long id)
    {
        try
        {
            var existing = await _supabaseService.GetPromotionByIdAsync(id);
            await _supabaseService.DeletePromotionAsync(id);
            if (existing != null && !string.IsNullOrWhiteSpace(existing.ImageUrl))
            {
                // The database record has been removed; storage cleanup must not undo that success.
                try { await _supabaseService.DeleteCatalogImageAsync(existing.ImageUrl); }
                catch { /* Orphaned storage objects can be cleaned up later. */ }
            }
            TempData["Success"] = "Promotion deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deleting promotion: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}