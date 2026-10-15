using CuttingEdge.ManagerPortal.Services;
using CuttingEdge.ManagerPortal.ViewModels;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class SchedulesController : Controller
{
    private readonly SupabaseService _supabaseService;

    public SchedulesController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Schedules
    public async Task<IActionResult> Index()
    {
        try
        {
            var schedules = await _supabaseService.GetWeeklySchedulesAsync();
            ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
            return View(schedules);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading schedules: {ex.Message}";
            return View();
        }
    }

    // GET: /Schedules/Add
    public async Task<IActionResult> Add()
    {
        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        return View();
    }

    // POST: /Schedules/Add
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Add(ScheduleViewModel model)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.SaveScheduleAsync(model);
                TempData["Success"] = "Schedule added successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error saving schedule: {ex.Message}");
            }
        }

        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        return View(model);
    }

    // GET: /Schedules/Edit/{stylistId}
    public async Task<IActionResult> Edit(Guid stylistId)
    {
        var schedule = await _supabaseService.GetStylistScheduleAsync(stylistId);
        if (schedule == null)
            return NotFound();

        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        ViewBag.Bookings = await _supabaseService.GetWeeklyBookingsByStylistAsync(stylistId);
        return View(schedule);
    }

    // POST: /Schedules/Edit/{stylistId}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Guid stylistId, ScheduleViewModel model)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdateScheduleAsync(stylistId, model);
                TempData["Success"] = "Schedule updated successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating schedule: {ex.Message}");
            }
        }

        ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
        return View(model);
    }

    // POST: /Schedules/Delete/{stylistId}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(Guid stylistId)
    {
        try
        {
            await _supabaseService.DeleteScheduleAsync(stylistId);
            TempData["Success"] = "Schedule deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deleting schedule: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}