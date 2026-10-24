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



using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using System.Text.RegularExpressions;
using System.Net.Mail;
using Microsoft.AspNetCore.RateLimiting;

namespace CuttingEdge.ManagerPortal.Controllers;

public class AccountController : Controller
{
    private readonly SupabaseService _supabaseService;
    private readonly ILogger<AccountController> _logger;

    public AccountController(SupabaseService supabaseService, ILogger<AccountController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    // ============ LOGIN ============
    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        ViewBag.ReturnUrl = returnUrl;
        return View();
    }

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

        // Supabase Auth is the only source of manager credentials.
        // A separate DefaultManager password must never bypass a password reset.
        try
        {
            var session = await _supabaseService.SignInAsync(email, password);
            if (session != null)
            {
                var userEmail = session.User?.Email ?? email;
                var profile = await _supabaseService.GetProfileByIdAsync(session.User!.Id);

                if (profile == null ||
                    !string.Equals(profile.Role, "Manager", StringComparison.OrdinalIgnoreCase) ||
                    !string.Equals(profile.Email, userEmail, StringComparison.OrdinalIgnoreCase))
                {
                    ModelState.AddModelError("", "This portal is for salon managers only.");
                    ViewBag.ReturnUrl = returnUrl;
                    return View();
                }

                HttpContext.Session.SetString("AccessToken", session.AccessToken ?? "");

                await SignInManager(profile.Id, profile.Email, profile.FullName, profile.Role, profile.Phone ?? "", profile.PhotoUrl);

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

    // ============ PASSWORD RECOVERY VIA SIX-DIGIT EMAIL OTP ============

    [HttpGet]
    public IActionResult ForgotPassword() => View();

    [HttpPost]
    [ValidateAntiForgeryToken] // Protects against CSRF on the login form
    [EnableRateLimiting("recovery-send")]
    public async Task<IActionResult> ForgotPassword(string email)
    {
        email = email?.Trim() ?? "";
        if (email.Length > 320 || !email.Contains('@'))
        {
            ModelState.AddModelError("", "Enter a valid email address.");
            return View();
        }

        try
        {
            // Fail visibly if essential server settings are missing, even when
            // the requested email address does not belong to a manager.
            _supabaseService.EnsureManagerRecoveryConfigured();

            // The app sends a six-digit manager recovery code using Email:SmtpHost.
            // Keep the response generic to prevent account enumeration.
            var profile = await _supabaseService.GetProfileByEmailAsync(email);
            if (profile != null &&
                string.Equals(profile.Role, "Manager", StringComparison.OrdinalIgnoreCase))
                await _supabaseService.SendManagerPasswordRecoveryEmailAsync(profile.Id, profile.Email);
        }
        catch (SupabaseException ex) when (ex.Status == System.Net.HttpStatusCode.TooManyRequests)
        {
            ModelState.AddModelError("", "Too many requests. Please wait before requesting another code.");
            return View();
        }
        catch (SmtpException ex)
        {
            _logger.LogError(ex,
                "Manager recovery SMTP delivery failed. SMTP status: {SmtpStatus}", ex.StatusCode);
            ModelState.AddModelError("",
                "The verification email could not be delivered. " +
                "Please contact the administrator to check SMTP settings and server logs.");
            return View();
        }
        catch (SupabaseException ex)
        {
            _logger.LogError(ex,
                "Manager recovery Supabase request failed. HTTP status: {HttpStatus}; code: {ApiCode}",
                (int)ex.Status, ex.Code ?? "unavailable");
            ModelState.AddModelError("",
                "Password recovery is temporarily unavailable. " +
                "Please contact the administrator to check Supabase setup.");
            return View();
        }
        catch (Exception ex)
        {
            // Never show SMTP credentials, service keys, or provider responses
            // in the browser. Detailed exceptions appear in server logs only.
            _logger.LogError(ex, "Manager recovery configuration or delivery failed.");
            ModelState.AddModelError("",
                "Unable to send a verification code right now. " +
                "Please contact the administrator to check server configuration and logs.");
            return View();
        }

        TempData["RecoveryEmail"] = email;
        return RedirectToAction(nameof(ForgotPasswordConfirmation));
    }

    [HttpGet]
    public IActionResult ForgotPasswordConfirmation()
    {
        var email = TempData.Peek("RecoveryEmail")?.ToString();
        if (string.IsNullOrWhiteSpace(email))
            return RedirectToAction(nameof(ForgotPassword));

        ViewBag.RecoveryEmail = email;
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting("recovery-verify")]
    public async Task<IActionResult> ForgotPasswordConfirmation(
        string email, string code, string newPassword, string confirmPassword)
    {
        email = email?.Trim() ?? "";
        ViewBag.RecoveryEmail = email;

        if (string.IsNullOrWhiteSpace(email) || email.Length > 320 || !email.Contains('@'))
            ModelState.AddModelError("", "Enter a valid email address.");
        if (!Regex.IsMatch(code ?? "", @"^[0-9]{6}$"))
            ModelState.AddModelError("", "Enter the six-digit code from your email.");
        if (string.IsNullOrEmpty(newPassword) || newPassword.Length < 8 || newPassword.Length > 128)
            ModelState.AddModelError("", "Password must be between 8 and 128 characters.");
        if (newPassword != confirmPassword)
            ModelState.AddModelError("", "Passwords do not match.");

        if (!ModelState.IsValid) return View();

        try
        {
            await _supabaseService.VerifyManagerSmtpCodeAndSetPasswordAsync(
                email, code ?? "", newPassword);

            TempData.Remove("RecoveryEmail");
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            HttpContext.Session.Clear();
            TempData["Success"] = "Your Supabase password was updated. Sign in with your new password.";
            return RedirectToAction(nameof(Login));
        }
        catch (UnauthorizedAccessException)
        {
            ModelState.AddModelError("", "This password-reset page is for manager accounts only.");
        }
        catch (SupabaseException ex) when (ex.Status == System.Net.HttpStatusCode.TooManyRequests)
        {
            ModelState.AddModelError("", "Too many attempts. Please wait and request a new code later.");
        }
        catch (Exception)
        {
            ModelState.AddModelError("", "The code is invalid, expired or already used, or the password could not be changed. If needed, request a new code.");
        }

        return View();
    }

    // Obsolete password-reset links are no longer used; start the OTP flow.
    [HttpGet]
    public IActionResult ResetPassword() => RedirectToAction(nameof(ForgotPassword));

    // ============ STYLIST INVITATION / SET PASSWORD ============
    // Public page reached from Supabase's invitation URL. Supabase supplies
    // access_token in the URL fragment, which the page copies to a POST form.
    [HttpGet]
    public IActionResult AcceptStylistInvite() => View();

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AcceptStylistInvite(string token, string newPassword, string confirmPassword)
    {
        ViewBag.Token = token;
        if (string.IsNullOrWhiteSpace(token))
            ModelState.AddModelError("", "The invitation link is missing or expired. Ask your manager for a new invitation.");
        if (string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 8)
            ModelState.AddModelError("", "Password must be at least 8 characters.");
        if (newPassword != confirmPassword)
            ModelState.AddModelError("", "Passwords do not match.");
        if (!ModelState.IsValid) return View();

        try
        {
            await _supabaseService.ResetPasswordAsync(token, newPassword);
            return View("StylistInviteComplete");
        }
        catch (Exception)
        {
            ModelState.AddModelError("", "Could not set your password. The invitation may have expired; ask your manager for a new link.");
            return View();
        }
    }

    // ============ LOGOUT ============

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await _supabaseService.SignOutAsync();
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        HttpContext.Session.Clear();
        return RedirectToAction(nameof(Login));
    }

    // ============ HELPER ============

    private async Task SignInManager(Guid? userId, string email, string fullName, string role, string phone, string? photoUrl)
    {
        HttpContext.Session.SetString("UserEmail", email);
        HttpContext.Session.SetString("UserRole", role);
        HttpContext.Session.SetString("FullName", fullName);
        if (userId.HasValue)
            HttpContext.Session.SetString("UserId", userId.Value.ToString());
        HttpContext.Session.SetString("PhotoUrl", photoUrl ?? "");

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.Name, email),
            new Claim(ClaimTypes.Email, email),
            new Claim(ClaimTypes.Role, role),
            new Claim("FullName", fullName),
            new Claim("Phone", phone ?? ""),
            new Claim("PhotoUrl", photoUrl ?? "")
        };

        if (userId.HasValue)
            claims.Add(new Claim(ClaimTypes.NameIdentifier, userId.Value.ToString()));

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        var principal = new ClaimsPrincipal(identity);

        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal);
    }
}