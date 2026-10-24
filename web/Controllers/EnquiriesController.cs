// ============================================================
// PROJECT: Cutting Edge Salon
// STUDENT DETAILS:
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
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text.RegularExpressions;

namespace CuttingEdge.ManagerPortal.Controllers;

[Authorize(Roles = "Manager")]
public class EnquiriesController : Controller
{
    // Service used to read/update customer enquiries and leave-request groups
    private readonly SupabaseService _supabase;
    // Logger for server-side diagnostics (exceptions are logged, not shown to users).
    private readonly ILogger<EnquiriesController> _logger;


    // Dependencies are injected by ASP.NET Core DI.
    public EnquiriesController(SupabaseService supabase, ILogger<EnquiriesController> logger)
    {
        _supabase = supabase;
        _logger = logger;
    }

    // <summary>
    // Defence-in-depth check: verifies the request is authenticated, has the
    // "Manager" role in claims, AND the session has a valid Manager role + user ID.
    // Returns true and outputs the manager's ID when all checks pass.
    // </summary>

    private bool ManagerId(out Guid id)
    {
        id = Guid.Empty;
        return User.Identity?.IsAuthenticated == true &&
               User.IsInRole("Manager") &&
               string.Equals(HttpContext.Session.GetString("UserRole"), "Manager",
                   StringComparison.OrdinalIgnoreCase) &&
               Guid.TryParse(HttpContext.Session.GetString("UserId"), out id);
    }

    // GET /Enquiries
    public async Task<IActionResult> Index(string? status = null)
    {
        if (!ManagerId(out _)) return Forbid();
        try
        {
            var list = await _supabase.GetCustomerEnquiriesAsync();
            ViewBag.OpenCount = list.Count(x => x.Status == "open");
            ViewBag.RepliedCount = list.Count(x => x.Status == "replied");
            ViewBag.SelectedStatus = status;
            if (status is "open" or "replied")
                list = list.Where(x => x.Status == status).ToList();

            ViewBag.PendingLeaveGroups = await _supabase.GetPendingLeaveRequestGroupsAsync();

            return View(list);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not load customer enquiries");
            TempData["Error"] = "Unable to load customer messages.";
            ViewBag.PendingLeaveGroups = new List<LeaveRequestGroup>();
            return View(new List<CustomerEnquiry>());
        }
    }

    // GET /Enquiries/Details/123
    // <summary>
    // Lists all customer enquiries. Optionally filters by status ("open" or "replied").
    // Also loads counts for the tabs and any pending leave-request groups.
    //</summary>
    public async Task<IActionResult> Details(long id)
    {
        if (!ManagerId(out _)) return Forbid();
        if (id <= 0)
        {
            TempData["Error"] = "Invalid enquiry ID.";
            return RedirectToAction(nameof(Index));
        }

        try
        {
            var enquiry = await _supabase.GetCustomerEnquiryAsync(id);
            if (enquiry == null) return NotFound();

            if (enquiry.Category == "stylist_leave_request")
            {
                var pendingGroups = await _supabase.GetPendingLeaveRequestGroupsAsync();

                // Match the exact group by stylist ID AND date range in the message,
                // so a stylist with several pending requests gets the right one.
                var stylistIdMatch = Regex.Match(enquiry.Message, @"Stylist ID:\s*(\d+)");
                var datesMatch = Regex.Match(enquiry.Message,
                    @"Dates:\s*(\d{4}-\d{2}-\d{2})\s*to\s*(\d{4}-\d{2}-\d{2})");
                if (stylistIdMatch.Success)
                {
                    long stylistId = long.Parse(stylistIdMatch.Groups[1].Value);
                    var candidates = pendingGroups.Where(g => g.StylistId == stylistId).ToList();
                    var matchedGroup = datesMatch.Success
                        ? candidates.FirstOrDefault(g =>
                            g.FirstDate.ToString("yyyy-MM-dd") == datesMatch.Groups[1].Value &&
                            g.LastDate.ToString("yyyy-MM-dd") == datesMatch.Groups[2].Value)
                        : candidates.FirstOrDefault();
                    ViewBag.LeaveGroupId = matchedGroup?.GroupId;
                }
            }

            return View(enquiry);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not open enquiry {EnquiryId}", id);
            TempData["Error"] = "Could not open this customer message.";
            return RedirectToAction(nameof(Index));
        }
    }

    // POST /Enquiries/Reply/123
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Reply(long id, string? replyMessage)
    {
        if (!ManagerId(out var managerId)) return Forbid();
        if (string.IsNullOrWhiteSpace(replyMessage) || replyMessage.Trim().Length > 5000)
        {
            TempData["Error"] = "Enter a reply of up to 5,000 characters.";
            return RedirectToAction(nameof(Details), new { id });
        }

        try
        {
            var sent = await _supabase.ReplyToCustomerEnquiryAsync(id, managerId, replyMessage);
            TempData[sent ? "Success" : "Error"] = sent
                ? "Reply saved and delivered."
                : "This enquiry has already been answered.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not reply to customer enquiry {EnquiryId}", id);
            TempData["Error"] = "Reply not sent.";
        }
        return RedirectToAction(nameof(Details), new { id });
    }

    // POST /Enquiries/ApproveLeave
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ApproveLeave(Guid groupId, long enquiryId, string managerNote)
    {
        if (!ManagerId(out _)) return Forbid();

        if (groupId == Guid.Empty || enquiryId <= 0)
        {
            TempData["Error"] = "Invalid leave request data.";
            return RedirectToAction(nameof(Index));
        }

        if (string.IsNullOrWhiteSpace(managerNote))
        {
            TempData["Error"] = "You must write a reply before approving the leave.";
            return RedirectToAction(nameof(Details), new { id = enquiryId });
        }

        try
        {
            await _supabase.ReviewLeaveRequestGroupAsync(groupId, approve: true, managerNote);
            TempData["Success"] = "Leave approved. The requested dates remain blocked.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Approving leave group {GroupId} failed", groupId);
            TempData["Error"] = "Could not approve the leave request: " + ex.Message;
        }
        return RedirectToAction(nameof(Details), new { id = enquiryId });
    }

    // POST /Enquiries/RejectLeave
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RejectLeave(Guid groupId, long enquiryId, string managerNote)
    {
        if (!ManagerId(out _)) return Forbid();

        if (groupId == Guid.Empty || enquiryId <= 0)
        {
            TempData["Error"] = "Invalid leave request data.";
            return RedirectToAction(nameof(Index));
        }

        if (string.IsNullOrWhiteSpace(managerNote))
        {
            TempData["Error"] = "You must write a reply before rejecting the leave.";
            return RedirectToAction(nameof(Details), new { id = enquiryId });
        }

        try
        {
            await _supabase.ReviewLeaveRequestGroupAsync(groupId, approve: false, managerNote);
            TempData["Success"] = "Leave rejected. The requested dates are available again.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Rejecting leave group {GroupId} failed", groupId);
            TempData["Error"] = "Could not reject the leave request: " + ex.Message;
        }
        return RedirectToAction(nameof(Details), new { id = enquiryId });
    }
}