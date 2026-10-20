using CuttingEdge.ManagerPortal.Models;
using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class BookingsController : Controller
{
    private readonly SupabaseService _supabaseService;
    private readonly ILogger<BookingsController> _logger;

    public BookingsController(SupabaseService supabaseService, ILogger<BookingsController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    // GET: /Bookings
    public async Task<IActionResult> Index(string? status, string? date, string? search)
    {
        try
        {
            var bookings = await _supabaseService.GetFilteredBookingsAsync(status, date, search);

            ViewBag.StatusFilter = status;
            ViewBag.DateFilter = date;
            ViewBag.SearchFilter = search;

            return View(bookings);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading bookings: {ex.Message}";
            return View(new List<Booking>());
        }
    }

    // GET: /Bookings/Details/{id}
    public async Task<IActionResult> Details(long id)
    {
        var booking = await _supabaseService.GetBookingByIdAsync(id);
        if (booking == null)
            return NotFound();

        return View(booking);
    }

    // GET: /Bookings/Reschedule/{id}
    public async Task<IActionResult> Reschedule(long id)
    {
        var booking = await _supabaseService.GetBookingByIdAsync(id);
        if (booking == null)
            return NotFound();

        if (booking.Status is "Completed" or "Cancelled")
        {
            TempData["Error"] = "Completed and cancelled appointments cannot be rescheduled.";
            return RedirectToAction(nameof(Details), new { id });
        }
        return View(booking);
    }

    // POST: /Bookings/Reschedule/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reschedule(long id, DateTime appointmentDate, TimeSpan startTime)
    {
        try
        {
            var booking = await _supabaseService.GetBookingByIdAsync(id);
            if (booking == null)
                return NotFound();

            // The RPC changes the appointment atomically and checks for overlaps.
            // Do not also patch the full Booking model: the date may have been saved
            // even when a subsequent unrelated field/notification update fails.
            var calculatedEnd = await _supabaseService.RescheduleBookingAsync(id, appointmentDate, startTime);
            TempData["Success"] = "Appointment rescheduled successfully.";

            // Notification errors should NEVER be shown as rescheduling failures;
            // the booking has already been updated by the RPC at this point.
            var failedRecipients = new List<string>();
            var message = $"Your appointment has been rescheduled to {appointmentDate:dd MMM yyyy} at {startTime:hh\\:mm}.";
            try
            {
                await _supabaseService.CreateNotificationAsync(
                    booking.CustomerId, "Appointment rescheduled", message, "booking");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Supabase customer reschedule notification failed for booking {BookingId}, profile {ProfileId}", id, booking.CustomerId);
                failedRecipients.Add("customer");
            }

            if (booking.Stylist != null && booking.Stylist.ProfileId != booking.CustomerId)
            {
                try
                {
                    await _supabaseService.CreateNotificationAsync(
                        booking.Stylist.ProfileId, "Appointment rescheduled",
                        $"An assigned appointment has moved to {appointmentDate:dd MMM yyyy} at {startTime:hh\\:mm}.",
                        "booking");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Supabase stylist reschedule notification failed for booking {BookingId}, profile {ProfileId}", id, booking.Stylist.ProfileId);
                    failedRecipients.Add("stylist");
                }
            }

            if (failedRecipients.Count != 0)
                TempData["Error"] = "The booking was rescheduled, but the " +
                    string.Join(" and ", failedRecipients) +
                    " notification could not be saved. Check the ASP.NET server logs for the exact Supabase error.";

            return RedirectToAction(nameof(Details), new { id });
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error rescheduling booking: {ex.Message}";
            return RedirectToAction(nameof(Details), new { id });
        }
    }

    // POST: /Bookings/Complete/{id}
    // Marks the appointment Completed. It then disappears from the stylist's schedule.
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Complete(long id, string? returnUrl = null)
    {
        try
        {
            await _supabaseService.UpdateBookingStatusAsync(id, "Completed");
            TempData["Success"] = "Appointment marked as completed.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error completing booking: {ex.Message}";
        }

        if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
            return Redirect(returnUrl);

        return RedirectToAction(nameof(Details), new { id });
    }

    // POST: /Bookings/Cancel/{id} - manager cancellation always requires a reason.
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Cancel(long id, string reason)
    {
        try
        {
            await _supabaseService.CancelBookingByManagerAsync(id, reason);
            TempData["Success"] = "Booking cancelled and the reason recorded.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Could not cancel booking: {ex.Message}";
        }
        return RedirectToAction(nameof(Details), new { id });
    }

    // GET: /Bookings/Edit/{id}
    public async Task<IActionResult> Edit(long id)
    {
        var booking = await _supabaseService.GetBookingByIdAsync(id);
        if (booking == null)
            return NotFound();

        return View(booking);
    }

    // POST: /Bookings/Edit/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, Booking booking)
    {
        if (id != booking.BookingId)
            return NotFound();

        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdateBookingAsync(booking);
                TempData["Success"] = "Booking updated successfully.";
                return RedirectToAction(nameof(Details), new { id });
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating booking: {ex.Message}");
            }
        }

        return View(booking);
    }
}
