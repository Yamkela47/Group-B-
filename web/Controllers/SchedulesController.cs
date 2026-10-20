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
    public async Task<IActionResult> Index(string? month, long? stylistId)
    {
        var first = DateTime.Today;
        if (!string.IsNullOrWhiteSpace(month) &&
            DateTime.TryParseExact(month + "-01", "yyyy-MM-dd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out var parsed))
            first = parsed;
        // Prevent extreme date ranges being requested from the UI.
        if (first.Year < 2020 || first.Year > 2100) first = DateTime.Today;
        try
        {
            return View(await _supabaseService.GetScheduleCalendarAsync(first, stylistId));
        }
        catch (Exception ex)
        {
            return View(new ScheduleCalendarViewModel
            {
                Month = new DateTime(first.Year, first.Month, 1),
                SelectedStylistId = stylistId,
                Error = $"Error loading schedules: {ex.Message}"
            });
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
    public async Task<IActionResult> Edit(long stylistId)
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
    public async Task<IActionResult> Edit(long stylistId, ScheduleViewModel model)
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
        ViewBag.Bookings = await _supabaseService.GetWeeklyBookingsByStylistAsync(stylistId);
        model.BlockedDates = await _supabaseService.GetBlockedDatesForStylistAsync(stylistId);
        model.StylistId = stylistId;
        model.StylistName = (await _supabaseService.GetStylistByIdAsync(stylistId))?.Profile?.FullName;
        return View(model);
    }

    // POST: /Schedules/Delete/{stylistId}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(long stylistId)
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
