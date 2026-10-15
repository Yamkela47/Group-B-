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
    public async Task<IActionResult> Create(Promotion promotion)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.CreatePromotionAsync(promotion);
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
    public async Task<IActionResult> Edit(Guid id)
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
    public async Task<IActionResult> Edit(Guid id, Promotion promotion)
    {
        if (id != promotion.PromotionId)
            return NotFound();

        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdatePromotionAsync(promotion);
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
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            await _supabaseService.DeletePromotionAsync(id);
            TempData["Success"] = "Promotion deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deleting promotion: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}