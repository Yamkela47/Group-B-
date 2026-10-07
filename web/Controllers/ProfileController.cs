using CuttingEdge.ManagerPortal.Models;
using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class ProfileController : Controller
{
    private readonly SupabaseService _supabaseService;

    public ProfileController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Profile
    public async Task<IActionResult> Index()
    {
        // Falls back to the demo manager when nobody has logged in yet.
        var email = HttpContext.Session.GetString("UserEmail") ?? "thabo@cuttingedge.co.za";

        try
        {
            var profile = await _supabaseService.GetProfileByEmailAsync(email);
            return View(profile);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading profile: {ex.Message}";
            return View(new Profile());
        }
    }

    // POST: /Profile/Update
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(Profile profile)
    {
        if (ModelState.IsValid)
        {
            try
            {
                await _supabaseService.UpdateProfileAsync(profile);
                TempData["Success"] = "Profile updated successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("", $"Error updating profile: {ex.Message}");
            }
        }

        return View("Index", profile);
    }

    // POST: /Profile/ChangePassword
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangePassword(string currentPassword, string newPassword, string confirmPassword)
    {
        if (newPassword != confirmPassword)
        {
            TempData["Error"] = "New passwords do not match.";
            return RedirectToAction(nameof(Index));
        }

        if (newPassword.Length < 8)
        {
            TempData["Error"] = "Password must be at least 8 characters.";
            return RedirectToAction(nameof(Index));
        }

        try
        {
            await _supabaseService.ChangePasswordAsync(currentPassword, newPassword);
            TempData["Success"] = "Password changed successfully.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Password change failed: {ex.Message}";
        }

        return RedirectToAction(nameof(Index));
    }
}