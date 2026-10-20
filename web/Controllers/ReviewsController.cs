using CuttingEdge.ManagerPortal.Services;
using CuttingEdge.ManagerPortal.ViewModels;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class ReviewsController : Controller
{
    private readonly SupabaseService _supabaseService;
    private readonly ILogger<ReviewsController> _logger;

    public ReviewsController(SupabaseService supabaseService, ILogger<ReviewsController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    private bool IsManager() =>
        string.Equals(HttpContext.Session.GetString("UserRole"), "Manager", StringComparison.OrdinalIgnoreCase)
        && !string.IsNullOrWhiteSpace(HttpContext.Session.GetString("UserEmail"));

    private static bool IsLowRating(CuttingEdge.ManagerPortal.Models.Review review) =>
        review.Rating <= 2 || (review.ServiceRating.HasValue && review.ServiceRating.Value <= 2);

    // GET: /Reviews
    public async Task<IActionResult> Index(string? rating, long? stylistId, DateTime? date, string? search)
    {
        if (!IsManager()) return Forbid();
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
            _logger.LogError(ex, "Unable to load customer reviews");
            TempData["Error"] = "Could not load reviews. Check the application logs.";
            return View(new List<CuttingEdge.ManagerPortal.Models.Review>());
        }
    }

    // GET: /Reviews/FollowUp/{id}
    public async Task<IActionResult> FollowUp(Guid id)
    {
        if (!IsManager()) return Forbid();
        try
        {
            var review = await _supabaseService.GetReviewByIdAsync(id);
            if (review == null) return NotFound();
            if (!IsLowRating(review)) return RedirectToAction(nameof(Index));

            return View(new ReviewFollowUpViewModel
            {
                Review = review,
                FollowUp = await _supabaseService.GetReviewFollowUpAsync(id)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unable to load follow-up for review {ReviewId}", id);
            TempData["Error"] = "Could not load this follow-up. Run Database/review_followups_setup.sql in Supabase first.";
            return RedirectToAction(nameof(Index));
        }
    }

    // POST: /Reviews/SendApologyNotification
    // Send one manager-written apology into the customer's Flutter notification inbox.
    // The Supabase RPC both inserts the notification and records its delivery in
    // one transaction, so retries cannot create duplicates.
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SendApologyNotification(Guid reviewId,
        string? apologySubject, string? apologyMessage)
    {
        if (!IsManager()) return Forbid();
        var returnRoute = new { id = reviewId };
        try
        {
            var review = await _supabaseService.GetReviewByIdAsync(reviewId);
            if (review == null) return NotFound();
            if (!IsLowRating(review) || review.Resolved)
            {
                TempData["Error"] = "Only unresolved one- or two-star reviews can be followed up.";
                return RedirectToAction(nameof(Index));
            }

            apologySubject = apologySubject?.Trim();
            apologyMessage = apologyMessage?.Trim();
            if (string.IsNullOrWhiteSpace(apologySubject) || apologySubject.Length > 180 ||
                string.IsNullOrWhiteSpace(apologyMessage) || apologyMessage.Length > 5000)
            {
                TempData["Error"] = "Enter an apology title (up to 180 characters) and message (up to 5,000 characters).";
                return RedirectToAction(nameof(FollowUp), returnRoute);
            }

            // The database function determines the recipient from reviews.customer_id,
            // not from an email address or profile ID provided by the browser.
            var managerEmail = HttpContext.Session.GetString("UserEmail")!;
            var created = await _supabaseService.SendReviewApologyNotificationAsync(
                reviewId, apologySubject, apologyMessage, managerEmail);
            TempData["Success"] = created
                ? "Apology sent to the customer's in-app Notifications inbox. No email was sent."
                : "The apology was already delivered. No duplicate notification was created.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to deliver in-app apology for review {ReviewId}", reviewId);
            TempData["Error"] = "Could not send the apology notification. Check the application logs and run Database/review_apology_notifications.sql in Supabase.";
        }
        return RedirectToAction(nameof(FollowUp), returnRoute);
    }

    // POST: /Reviews/SendStylistReportNotification
    // Sends the manager-written report to the review's assigned stylist.
    // The database selects the stylist's profile and prevents repeat delivery.
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SendStylistReportNotification(Guid reviewId,
        string? stylistReportTitle, string? stylistReportMessage)
    {
        if (!IsManager()) return Forbid();
        var returnRoute = new { id = reviewId };
        try
        {
            var review = await _supabaseService.GetReviewByIdAsync(reviewId);
            if (review == null) return NotFound();
            if (!IsLowRating(review))
            {
                TempData["Error"] = "Only one- or two-star reviews can be followed up.";
                return RedirectToAction(nameof(Index));
            }

            stylistReportTitle = stylistReportTitle?.Trim();
            stylistReportMessage = stylistReportMessage?.Trim();
            if (string.IsNullOrWhiteSpace(stylistReportTitle) || stylistReportTitle.Length > 180 ||
                string.IsNullOrWhiteSpace(stylistReportMessage) || stylistReportMessage.Length > 5000)
            {
                TempData["Error"] = "Enter a report title (up to 180 characters) and message (up to 5,000 characters).";
                return RedirectToAction(nameof(FollowUp), returnRoute);
            }

            var managerEmail = HttpContext.Session.GetString("UserEmail")!;
            var created = await _supabaseService.SendReviewStylistReportNotificationAsync(
                reviewId, stylistReportTitle, stylistReportMessage, managerEmail);
            TempData["Success"] = created
                ? "Feedback report sent to the stylist's Flutter Notifications inbox. No email was sent."
                : "The stylist has already received this report. No duplicate notification was created.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to deliver stylist report for review {ReviewId}", reviewId);
            TempData["Error"] = "Could not send the stylist report. Check the application logs and run Database/review_stylist_report_notifications.sql in Supabase.";
        }
        return RedirectToAction(nameof(FollowUp), returnRoute);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> MarkResolved(Guid id)
    {
        if (!IsManager()) return Forbid();
        try
        {
            var review = await _supabaseService.GetReviewByIdAsync(id);
            if (review == null) return NotFound();
            if (!IsLowRating(review)) return BadRequest("Follow-up is only for low ratings.");
            await _supabaseService.MarkReviewResolvedAsync(id);
            TempData["Success"] = "Review follow-up marked as resolved.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(FollowUp), new { id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unable to resolve review {ReviewId}", id);
            TempData["Error"] = "Could not resolve the review. Check the application logs.";
            return RedirectToAction(nameof(FollowUp), new { id });
        }
        return RedirectToAction(nameof(Index));
    }
}
