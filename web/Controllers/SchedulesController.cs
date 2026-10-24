// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

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

    // GET: /Schedules/Edit/{stylistId}?week=2026-10-19
    public async Task<IActionResult> Edit(long stylistId, string? week = null)
    {
        DateTime? requested = null;
        if (!string.IsNullOrWhiteSpace(week))
        {
            if (!DateTime.TryParseExact(week, "yyyy-MM-dd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out var parsed))
                return BadRequest("Invalid week date.");
            requested = parsed;
        }

        try
        {
            var schedule = await _supabaseService.GetStylistWeekEditAsync(stylistId, requested);
            if (schedule == null) return NotFound();
            ViewBag.Bookings = await _supabaseService.GetWeeklyBookingsByStylistAsync(stylistId, schedule.WeekStart);
            ViewBag.PendingLeaveGroups = await _supabaseService.GetPendingLeaveRequestGroupsForStylistAsync(stylistId);
            return View(schedule);
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(Index));
        }
    }

    // POST: Save only the selected actual week (NOT the recurring weekday pattern).
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long stylistId, ScheduleViewModel model)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdateSpecificWeekAsync(stylistId, model);
                TempData["Success"] = "This week's schedule was updated successfully.";
                return RedirectToAction(nameof(Edit), new
                {
                    stylistId,
                    week = model.WeekStart.ToString("yyyy-MM-dd")
                });
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating schedule: {ex.Message}");
            }
        }

        try
        {
            var current = await _supabaseService.GetStylistWeekEditAsync(stylistId, model.WeekStart);
            if (current == null) return NotFound();
            ViewBag.Bookings = await _supabaseService.GetWeeklyBookingsByStylistAsync(stylistId, current.WeekStart);
            ViewBag.PendingLeaveGroups = await _supabaseService.GetPendingLeaveRequestGroupsForStylistAsync(stylistId);
            return View(current);
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(Index));
        }
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