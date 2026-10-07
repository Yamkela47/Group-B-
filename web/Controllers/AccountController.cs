using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CuttingEdge.ManagerPortal.Controllers;

public class AccountController : Controller
{
    private readonly SupabaseService _supabaseService;

    public AccountController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // ============ LOGIN ============

    // GET: /Account/Login
    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        ViewBag.ReturnUrl = returnUrl;
        return View();
    }

    // POST: /Account/Login
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(string email, string password, string? returnUrl = null)
    {
        if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(password))
        {
            ModelState.AddModelError("", "Email and password are required.");
            ViewBag.ReturnUrl = returnUrl;
            return View();
        }

        try
        {
            var session = await _supabaseService.SignInAsync(email, password);
            if (session != null)
            {
                // Store session data
                HttpContext.Session.SetString("AccessToken", session.AccessToken ?? "");
                HttpContext.Session.SetString("UserEmail", session.User?.Email ?? "");
                HttpContext.Session.SetString("UserRole", "Manager");

                // Create authentication cookie
                var claims = new List<Claim>
                {
                    new Claim(ClaimTypes.Name, session.User?.Email ?? ""),
                    new Claim(ClaimTypes.Email, session.User?.Email ?? ""),
                    new Claim(ClaimTypes.Role, "Manager"),
                    new Claim("FullName", "Thabo Mokwena")
                };

                var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
                var principal = new ClaimsPrincipal(identity);

                await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal);

                // Redirect
                if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
                    return Redirect(returnUrl);

                return RedirectToAction("Index", "Dashboard");
            }

            ModelState.AddModelError("", "Invalid email or password.");
        }
        catch (Exception ex)
        {
            ModelState.AddModelError("", $"Login failed: {ex.Message}");
        }

        ViewBag.ReturnUrl = returnUrl;
        return View();
    }

    // ============ FORGOT PASSWORD ============

    // GET: /Account/ForgotPassword
    [HttpGet]
    public IActionResult ForgotPassword()
    {
        return View();
    }

    // POST: /Account/ForgotPassword
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ForgotPassword(string email)
    {
        if (string.IsNullOrEmpty(email))
        {
            ModelState.AddModelError("", "Email is required.");
            return View();
        }

        try
        {
            await _supabaseService.SendPasswordResetEmailAsync(email);
            return RedirectToAction(nameof(ForgotPasswordConfirmation));
        }
        catch (Exception ex)
        {
            ModelState.AddModelError("", $"Error sending reset email: {ex.Message}");
            return View();
        }
    }

    // GET: /Account/ForgotPasswordConfirmation
    [HttpGet]
    public IActionResult ForgotPasswordConfirmation()
    {
        return View();
    }

    // ============ RESET PASSWORD ============

    // GET: /Account/ResetPassword
    [HttpGet]
    public IActionResult ResetPassword(string token)
    {
        ViewBag.Token = token;
        return View();
    }

    // POST: /Account/ResetPassword
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetPassword(string token, string newPassword, string confirmPassword)
    {
        if (newPassword != confirmPassword)
        {
            ModelState.AddModelError("", "Passwords do not match.");
            return View();
        }

        if (newPassword.Length < 8)
        {
            ModelState.AddModelError("", "Password must be at least 8 characters.");
            return View();
        }

        try
        {
            await _supabaseService.ResetPasswordAsync(token, newPassword);
            TempData["Success"] = "Password reset successfully. Please log in.";
            return RedirectToAction(nameof(Login));
        }
        catch (Exception ex)
        {
            ModelState.AddModelError("", $"Password reset failed: {ex.Message}");
            return View();
        }
    }

    // ============ LOGOUT ============

    // POST: /Account/Logout
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await _supabaseService.SignOutAsync();
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        HttpContext.Session.Clear();
        return RedirectToAction(nameof(Login));
    }
}