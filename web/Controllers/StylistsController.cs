using CuttingEdge.ManagerPortal.Services;
using CuttingEdge.ManagerPortal.ViewModels;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class StylistsController : Controller
{
    private readonly SupabaseService _supabaseService;

    public StylistsController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Stylists
    public async Task<IActionResult> Index()
    {
        try
        {
            var stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
            return View(stylists);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading stylists: {ex.Message}";
            return View(new List<CuttingEdge.ManagerPortal.Models.Stylist>());
        }
    }

    // GET: /Stylists/Details/{id}
    public async Task<IActionResult> Details(Guid id)
    {
        var stylist = await _supabaseService.GetStylistByIdAsync(id);
        if (stylist == null)
            return NotFound();

        return View(stylist);
    }

    // GET: /Stylists/Create
    public async Task<IActionResult> Create()
    {
        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View();
    }

    // POST: /Stylists/Create
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(StylistViewModel model)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.CreateStylistAsync(model);
                TempData["Success"] = "Stylist added successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error creating stylist: {ex.Message}");
            }
        }

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(model);
    }

    // GET: /Stylists/Edit/{id}
    public async Task<IActionResult> Edit(Guid id)
    {
        var model = await _supabaseService.GetStylistViewModelAsync(id);
        if (model == null)
            return NotFound();

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(model);
    }

    // POST: /Stylists/Edit/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Guid id, StylistViewModel model)
    {
        if (id != model.StylistId)
            return NotFound();

        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdateStylistAsync(model);
                TempData["Success"] = "Stylist updated successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating stylist: {ex.Message}");
            }
        }

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(model);
    }

    // POST: /Stylists/Deactivate/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(Guid id)
    {
        try
        {
            await _supabaseService.DeactivateStylistAsync(id);
            TempData["Success"] = "Stylist deactivated.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deactivating stylist: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }

    // POST: /Stylists/Delete/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            await _supabaseService.DeleteStylistAsync(id);
            TempData["Success"] = "Stylist removed.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deleting stylist: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}