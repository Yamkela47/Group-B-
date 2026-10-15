using CuttingEdge.ManagerPortal.Models;
using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class BookingsController : Controller
{
    private readonly SupabaseService _supabaseService;

    public BookingsController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
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
    public async Task<IActionResult> Details(Guid id)
    {
        var booking = await _supabaseService.GetBookingByIdAsync(id);
        if (booking == null)
            return NotFound();

        return View(booking);
    }

    // GET: /Bookings/Reschedule/{id}
    public async Task<IActionResult> Reschedule(Guid id)
    {
        var booking = await _supabaseService.GetBookingByIdAsync(id);
        if (booking == null)
            return NotFound();

        return View(booking);
    }

    // POST: /Bookings/Reschedule/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reschedule(Guid id, DateTime appointmentDate, TimeSpan startTime, TimeSpan endTime)
    {
        try
        {
            var booking = await _supabaseService.GetBookingByIdAsync(id);
            if (booking == null)
                return NotFound();

            // Update the appointment time
            booking.AppointmentDate = appointmentDate;
            booking.StartTime = startTime;
            booking.EndTime = endTime;

            await _supabaseService.UpdateBookingAsync(booking);

            // Optional: create a notification for the customer
            await _supabaseService.CreateNotificationAsync(
                booking.CustomerId,
                "Appointment Rescheduled",
                $"Your appointment has been rescheduled to {appointmentDate:dd MMM yyyy} at {startTime:hh\\:mm}.",
                "Booking"
            );

            TempData["Success"] = "Appointment rescheduled successfully.";
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
    public async Task<IActionResult> Complete(Guid id, string? returnUrl = null)
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

    // GET: /Bookings/Edit/{id}
    public async Task<IActionResult> Edit(Guid id)
    {
        var booking = await _supabaseService.GetBookingByIdAsync(id);
        if (booking == null)
            return NotFound();

        return View(booking);
    }

    // POST: /Bookings/Edit/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Guid id, Booking booking)
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