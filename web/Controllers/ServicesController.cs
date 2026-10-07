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
    public async Task<IActionResult> Create(Service service)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.CreateServiceAsync(service);
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
    public async Task<IActionResult> Edit(Guid id)
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
    public async Task<IActionResult> Edit(Guid id, Service service)
    {
        if (id != service.ServiceId)
            return NotFound();

        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdateServiceAsync(service);
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
    public async Task<IActionResult> Delete(Guid id)
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