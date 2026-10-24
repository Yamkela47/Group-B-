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

public class StylistsController : Controller
{
    private readonly SupabaseService _supabaseService;
    private readonly ILogger<StylistsController> _logger;

    public StylistsController(
        SupabaseService supabaseService,
        ILogger<StylistsController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    // GET: /Stylists
    public async Task<IActionResult> Index()
    {
        try
        {
            var stylists = await _supabaseService.GetAllStylistsWithProfilesAsync();
            return View(stylists);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading stylists: {ex.Message}";
            return View(new List<CuttingEdge.ManagerPortal.Models.Stylist>());
        }
    }

    // GET: /Stylists/Details/{id}
    public async Task<IActionResult> Details(long id)
    {
        var stylist = await _supabaseService.GetStylistByIdAsync(id);
        if (stylist == null)
            return NotFound();

        ViewBag.Services = await _supabaseService.GetServicesForStylistAsync(id);
        ViewBag.Reviews = await _supabaseService.GetReviewsForStylistAsync(id);
        // Show every date, including blocked dates and days with no scheduled shift.
        ViewBag.AvailabilityDays = await _supabaseService.GetStylistAvailabilityForDetailsAsync(id);
        // Also show future leave beyond the four-week schedule preview.
        ViewBag.BlockedDates = await _supabaseService.GetBlockedDatesForStylistAsync(id);
        // A paginated, lightweight summary ensures the star counts are not limited
        // by the review list's 500-record display limit.
        ViewBag.RatingSummary = await _supabaseService.GetStylistRatingSummaryAsync(id);
        return View(stylist);
    }

    // GET: /Stylists/Create
    public async Task<IActionResult> Create()
    {
        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View();
    }

    // POST: /Stylists/Create
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(StylistViewModel model, IFormFile? photoFile)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.CreateStylistAsync(model);
                if (photoFile != null && photoFile.Length > 0)
                {
                    // Images are saved under catalog-images/stylists/<profile-id>/.
                    try
                    {
                        var created = await _supabaseService.GetProfileByEmailAsync(model.Email);
                        if (created != null)
                            await _supabaseService.UploadProfilePhotoAsync(created.Id, photoFile, "stylists");
                    }
                    catch (Exception photoError)
                    {
                        // The account is already created; never report creation failed.
                        TempData["Warning"] = "The stylist was created but their photo could not be uploaded: " + photoError.Message;
                    }
                }
                TempData["Success"] = string.IsNullOrWhiteSpace(model.InitialPassword)
                    ? "Stylist added. A password setup invitation was sent by Supabase."
                    : "Stylist added. They can sign in to Flutter using the email and initial password you provided.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error creating stylist: {ex.Message}");
            }
        }

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(model);
    }

    // GET: /Stylists/Edit/{id}
    public async Task<IActionResult> Edit(long id)
    {
        var model = await _supabaseService.GetStylistViewModelAsync(id);
        if (model == null)
            return NotFound();

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(model);
    }

    // POST: /Stylists/Edit/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, StylistViewModel model, IFormFile? photoFile)
    {
        if (id != model.StylistId)
            return NotFound();

        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdateStylistAsync(model);
                if (photoFile != null && photoFile.Length > 0)
                {
                    try
                    {
                        var savedStylist = await _supabaseService.GetStylistByIdAsync(id);
                        if (savedStylist != null)
                            await _supabaseService.UploadProfilePhotoAsync(savedStylist.ProfileId, photoFile, "stylists");
                    }
                    catch (Exception photoError)
                    {
                        TempData["Warning"] = "Stylist details saved, but photo upload failed: " + photoError.Message;
                    }
                }
                TempData["Success"] = "Stylist updated successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating stylist: {ex.Message}");
            }
        }

        ViewBag.Services = await _supabaseService.GetAllServicesAsync();
        return View(model);
    }

    // POST: /Stylists/ResetPassword/{id}
    // Requires a signed-in manager and an anti-forgery token. The password
    // is posted separately from Edit Stylist so it is never saved by the
    // normal profile-update operation or placed in a URL.
    [HttpPost]
    [Microsoft.AspNetCore.Authorization.Authorize(Roles = "Manager")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetPassword(
        long id, CuttingEdge.ManagerPortal.ViewModels.StylistPasswordUpdateViewModel model)
    {
        if (!ModelState.IsValid || string.IsNullOrWhiteSpace(model.NewPassword))
        {
            TempData["Error"] = "Password not updated. Enter a password of at least 8 characters and confirm it correctly.";
            return RedirectToAction(nameof(Edit), new { id });
        }

        try
        {
            await _supabaseService.ResetStylistPasswordAsync(id, model.NewPassword);
            TempData["Success"] = "Stylist password updated in Supabase Auth. The stylist can now use the new password in Flutter.";
        }
        catch (SupabaseException ex)
        {
            // Log only the response status/code, not passwords, keys or request bodies.
            _logger.LogError(ex,
                "Stylist {StylistId} password reset failed: Supabase HTTP {Status}, code {Code}",
                id, (int)ex.Status, ex.Code);

            TempData["Error"] = ex.Status switch
            {
                System.Net.HttpStatusCode.Unauthorized or System.Net.HttpStatusCode.Forbidden =>
                    "Supabase rejected the server's Auth Admin credentials. Check Supabase:ServiceRoleKey on the ASP.NET server (not Flutter).",
                System.Net.HttpStatusCode.NotFound =>
                    "The stylist's Supabase Auth account could not be found. Check Database/check_stylist_auth_link.sql.",
                System.Net.HttpStatusCode.UnprocessableEntity or System.Net.HttpStatusCode.BadRequest =>
                    "Supabase rejected the password update. Check the Visual Studio Output logs for its error code and message.",
                _ => "Supabase Auth returned an error while updating the password. Check the Visual Studio Output logs."
            };
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("Stylist {StylistId} password reset stopped: {Reason}", id, ex.Message);
            TempData["Error"] = ex.Message;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected password reset error for stylist {StylistId}", id);
            TempData["Error"] = "The password could not be updated. Check Visual Studio logs.";
        }

        return RedirectToAction(nameof(Edit), new { id });
    }

    // POST: /Stylists/Deactivate/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(long id)
    {
        try
        {
            await _supabaseService.DeactivateStylistAsync(id);
            TempData["Success"] = "Stylist deactivated.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deactivating stylist: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }

    // POST: /Stylists/Delete/{id}
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(long id)
    {
        try
        {
            await _supabaseService.DeleteStylistAsync(id);
            TempData["Success"] = "Stylist removed.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error deleting stylist: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}