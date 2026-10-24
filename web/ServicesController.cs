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

public class ServicesController : Controller
{
    private readonly SupabaseService _supabaseService;

    public ServicesController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Services
    public async Task<IActionResult> Index()
    {
        try
        {
            var services = await _supabaseService.GetAllServicesAsync();
            var promotions = await _supabaseService.GetActivePromotionsAsync();

            var viewModel = new ServicesPromotionsViewModel
            {
                Services = services,
                Promotions = promotions
            };

            return View(viewModel);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading services: {ex.Message}";
            return View(new ServicesPromotionsViewModel());
        }
    }

    // GET: /Services/Create
    public async Task<IActionResult> Create()
    {
        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        return View();
    }

    // POST: /Services/Create
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Service service, IFormFile? imageFile)
    {
        if (ModelState.IsValid)
        {
            try
            {
                service.ImageUrl = null;
                if (imageFile != null && imageFile.Length > 0)
                    service.ImageUrl = await _supabaseService.UploadCatalogImageAsync(imageFile, "services");
                try { await _supabaseService.CreateServiceAsync(service); }
                catch
                {
                    if (service.ImageUrl != null)
                        try { await _supabaseService.DeleteCatalogImageAsync(service.ImageUrl); } catch { }
                    throw;
                }
                TempData["Success"] = "Service created successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error creating service: {ex.Message}");
            }
        }

        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        return View(service);
    }

    // GET: /Services/Edit/{id}
    public async Task<IActionResult> Edit(long id)
    {
        var service = await _supabaseService.GetServiceByIdAsync(id);
        if (service == null)
            return NotFound();

        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        ViewBag.AllServices = await _supabaseService.GetAllServicesAsync();
        return View(service);
    }

    // POST: /Services/Edit/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, Service service, IFormFile? imageFile, bool removeImage = false)
    {
        if (id != service.ServiceId)
            return NotFound();

        if (ModelState.IsValid)
        {
            try
            {
                var existing = await _supabaseService.GetServiceByIdAsync(id);
                if (existing == null) return NotFound();
                service.ImageUrl = existing.ImageUrl;
                string? uploaded = null;
                if (imageFile != null && imageFile.Length > 0)
                    service.ImageUrl = uploaded = await _supabaseService.UploadCatalogImageAsync(imageFile, "services");
                else if (removeImage)
                    service.ImageUrl = null;
                try { await _supabaseService.UpdateServiceAsync(service); }
                catch
                {
                    if (uploaded != null)
                        try { await _supabaseService.DeleteCatalogImageAsync(uploaded); } catch { }
                    throw;
                }
                if (existing.ImageUrl != service.ImageUrl)
                    try { await _supabaseService.DeleteCatalogImageAsync(existing.ImageUrl); } catch { }
                TempData["Success"] = "Service updated successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating service: {ex.Message}");
            }
        }

        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        ViewBag.AllServices = await _supabaseService.GetAllServicesAsync();
        return View(service);
    }

    // POST: /Services/Delete/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(long id)
    {
        try
        {
            await _supabaseService.DeleteServiceAsync(id);
            TempData["Success"] = "Service deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deleting service: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}