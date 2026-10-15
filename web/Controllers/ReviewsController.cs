using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class ReviewsController : Controller
{
    private readonly SupabaseService _supabaseService;

    public ReviewsController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Reviews
    public async Task<IActionResult> Index(string? rating, Guid? stylistId, DateTime? date, string? search)
    {
        try
        {
            var reviews = await _supabaseService.GetFilteredReviewsAsync(rating, stylistId, date, search);
            var summary = await _supabaseService.GetReviewSummaryAsync();

            ViewBag.RatingFilter = rating;
            ViewBag.StylistFilter = stylistId;
            ViewBag.DateFilter = date;
            ViewBag.SearchFilter = search;
            ViewBag.Summary = summary;
            ViewBag.Stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();

            return View(reviews);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading reviews: {ex.Message}";
            return View(new List<CuttingEdge.ManagerPortal.Models.Review>());
        }
    }

    // GET: /Reviews/FollowUp/{id}
    public async Task<IActionResult> FollowUp(Guid id)
    {
        var review = await _supabaseService.GetReviewByIdAsync(id);
        if (review == null)
            return NotFound();

        return View(review);
    }

    // POST: /Reviews/SendApology
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SendApology(Guid reviewId, string email, string subject, string message)
    {
        try
        {
            await _supabaseService.SendEmailAsync(email, subject, message);
            TempData["Success"] = "Apology sent to customer.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error sending apology: {ex.Message}";
        }

        return RedirectToAction(nameof(FollowUp), new { id = reviewId });
    }

    // POST: /Reviews/SendReportToStylist
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SendReportToStylist(Guid reviewId, string email, string note, bool ccManager)
    {
        try
        {
            await _supabaseService.SendEmailAsync(email, "Customer Feedback Report", note);

            if (ccManager)
            {
                var managerEmail = HttpContext.Session.GetString("UserEmail");
                if (!string.IsNullOrEmpty(managerEmail))
                    await _supabaseService.SendEmailAsync(managerEmail, "CC: Customer Feedback Report", note);
            }

            TempData["Success"] = "Report sent to stylist.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error sending report: {ex.Message}";
        }

        return RedirectToAction(nameof(FollowUp), new { id = reviewId });
    }

    // POST: /Reviews/MarkResolved/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> MarkResolved(Guid id)
    {
        try
        {
            await _supabaseService.MarkReviewResolvedAsync(id);
            TempData["Success"] = "Review marked as resolved.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error resolving review: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}