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
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Net.Mail;
using System.Security.Claims;

namespace CuttingEdge.ManagerPortal.Controllers;

[Authorize(Roles = "Manager")]
public class ProfileController : Controller
{
    private readonly SupabaseService _supabaseService;
    private readonly ILogger<ProfileController> _logger;

    private static readonly HashSet<string> AllowedBranches = new(StringComparer.Ordinal)
    {
        "Cutting Edge — Welkom Central",
        "Cutting Edge — Bloemfontein CBD"
    };

    public ProfileController(SupabaseService supabaseService, ILogger<ProfileController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    private async Task<Profile?> SignedInManagerAsync()
    {
        // Never trust a posted Id, email, role or profile photo URL.
        var idText = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? HttpContext.Session.GetString("UserId");
        Profile? profile = null;
        if (Guid.TryParse(idText, out var id) && id != Guid.Empty)
            profile = await _supabaseService.GetProfileByIdAsync(id);
        else
        {
            // Compatibility with older manager cookies lacking NameIdentifier.
            var email = User.FindFirst(ClaimTypes.Email)?.Value
                ?? HttpContext.Session.GetString("UserEmail");
            if (!string.IsNullOrWhiteSpace(email))
                profile = await _supabaseService.GetProfileByEmailAsync(email);
        }

        return string.Equals(profile?.Role, "Manager", StringComparison.OrdinalIgnoreCase)
            ? profile : null;
    }

    [HttpGet]
    public async Task<IActionResult> Index()
    {
        try
        {
            var profile = await SignedInManagerAsync();
            if (profile == null)
                return Forbid();
            return View(profile);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not load manager profile");
            TempData["Error"] = "Unable to load the manager profile from Supabase. Check the profile schema and server logs.";
            return View(new Profile());
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Update([Bind("FullName,Email,Phone,Branch")] Profile input)
    {
        Profile? existing;
        try
        {
            existing = await SignedInManagerAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Manager lookup failed while editing profile");
            TempData["Error"] = "Could not verify your manager profile. Please sign in again.";
            return RedirectToAction(nameof(Index));
        }
        if (existing == null) return Forbid();

        input.FullName = (input.FullName ?? "").Trim();
        input.Email = (input.Email ?? "").Trim();
        input.Phone = string.IsNullOrWhiteSpace(input.Phone) ? null : input.Phone.Trim();
        input.Branch = string.IsNullOrWhiteSpace(input.Branch) ? null : input.Branch.Trim();

        if (input.FullName.Length is < 2 or > 150)
            ModelState.AddModelError(nameof(input.FullName), "Enter a name between 2 and 150 characters.");
        if (input.Email.Length > 254 || !MailAddress.TryCreate(input.Email, out var parsed) ||
            !string.Equals(parsed.Address, input.Email, StringComparison.OrdinalIgnoreCase))
            ModelState.AddModelError(nameof(input.Email), "Enter a valid email address.");
        if (input.Phone?.Length > 30)
            ModelState.AddModelError(nameof(input.Phone), "Phone numbers must be 30 characters or fewer.");
        if (input.Branch != null && !AllowedBranches.Contains(input.Branch))
            ModelState.AddModelError(nameof(input.Branch), "Select a listed branch.");

        if (!ModelState.IsValid)
        {
            input.Id = existing.Id;
            input.Role = existing.Role;
            input.PhotoUrl = existing.PhotoUrl;
            input.CreatedAt = existing.CreatedAt;
            return View("Index", input);
        }

        try
        {
            // Service verifies a matching Supabase Auth user for email changes,
            // writes profile fields to the database, then reloads the stored row.
            var saved = await _supabaseService.UpdateProfileAsync(new Profile
            {
                Id = existing.Id,
                FullName = input.FullName,
                Email = input.Email,
                Phone = input.Phone,
                Branch = input.Branch
            });
            await RefreshAuthCookieAsync(saved);
            TempData["Success"] = "Manager profile saved to Supabase successfully.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Updating manager profile {ProfileId} failed", existing.Id);
            TempData["Error"] = "Could not save the manager profile: " + ex.Message;
        }
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UploadPhoto(IFormFile? photo)
    {
        if (photo == null || photo.Length == 0)
        {
            TempData["Error"] = "Choose a JPG or PNG photo first.";
            return RedirectToAction(nameof(Index));
        }
        try
        {
            var profile = await SignedInManagerAsync();
            if (profile == null) return Forbid();

            await _supabaseService.UploadProfilePhotoAsync(profile.Id, photo, "managers");
            // Reload the saved URL from Supabase rather than trusting the POST.
            var updated = await _supabaseService.GetProfileByIdAsync(profile.Id)
                ?? throw new InvalidOperationException("The uploaded profile could not be reloaded.");
            await RefreshAuthCookieAsync(updated);
            TempData["Success"] = "Manager photo saved to Supabase and updated in the header.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Manager profile photo upload failed");
            TempData["Error"] = "Photo upload failed: " + ex.Message;
        }
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangePassword(string? currentPassword, string? newPassword, string? confirmPassword)
    {
        if (string.IsNullOrWhiteSpace(currentPassword))
            TempData["Error"] = "Enter your current Supabase password.";
        else if (string.IsNullOrEmpty(newPassword) || newPassword.Length < 8 ||
            !newPassword.Any(char.IsUpper) || !newPassword.Any(char.IsDigit) ||
            !newPassword.Any(c => !char.IsLetterOrDigit(c)))
            TempData["Error"] = "Use 8+ characters, including an uppercase letter, a number and a symbol.";
        else if (newPassword != confirmPassword)
            TempData["Error"] = "New passwords do not match.";
        else
        {
            try
            {
                if (await SignedInManagerAsync() == null) return Forbid();
                await _supabaseService.ChangePasswordAsync(currentPassword, newPassword);
                TempData["Success"] = "Supabase Auth password updated. Use the new password when signing in again.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Manager password change failed");
                TempData["Error"] = "Password update failed: " + ex.Message;
            }
        }
        return RedirectToAction(nameof(Index));
    }

    private async Task RefreshAuthCookieAsync(Profile profile)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, profile.Id.ToString()),
            new(ClaimTypes.Name, profile.Email),
            new(ClaimTypes.Email, profile.Email),
            new(ClaimTypes.Role, profile.Role),
            new("FullName", profile.FullName),
            new("Phone", profile.Phone ?? ""),
            new("Branch", profile.Branch ?? ""),
            new("PhotoUrl", profile.PhotoUrl ?? "")
        };

        HttpContext.Session.SetString("UserId", profile.Id.ToString());
        HttpContext.Session.SetString("UserEmail", profile.Email);
        HttpContext.Session.SetString("FullName", profile.FullName);
        HttpContext.Session.SetString("UserRole", profile.Role);
        HttpContext.Session.SetString("Branch", profile.Branch ?? "");
        HttpContext.Session.SetString("PhotoUrl", profile.PhotoUrl ?? "");

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity));
    }
}
