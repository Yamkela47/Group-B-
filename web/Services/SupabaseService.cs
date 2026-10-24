using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Mail;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using CuttingEdge.ManagerPortal.Models;
using CuttingEdge.ManagerPortal.ViewModels;

namespace CuttingEdge.ManagerPortal.Services;

// ---------------------------------------------------------------------------
//  LIVE SUPABASE VERSION
//  Talks to Supabase over its REST APIs (PostgREST for tables, GoTrue for auth,
//  Storage for images).
//
//  Configuration:
//    Supabase:Url             https://<project>.supabase.co
//    Supabase:AnonKey         public anon key
//    Supabase:ServiceRoleKey  secret service key (server-side only)
// ---------------------------------------------------------------------------

/// <summary>Minimal representation of an authenticated Supabase user.</summary>
public class AuthUser
{
    public Guid Id { get; set; }
    public string? Email { get; set; }
}

/// <summary>Result of a successful Supabase sign-in.</summary>
public class AuthSession
{
    public string? AccessToken { get; set; }
    public AuthUser? User { get; set; }
}

/// <summary>Carries Supabase HTTP status + Postgres/PostgREST error code to callers.</summary>
public class SupabaseException : InvalidOperationException
{
    public HttpStatusCode Status { get; }
    public string? Code { get; }

    public SupabaseException(string message, HttpStatusCode status, string? code)
        : base(message)
    {
        Status = status;
        Code = code;
    }
}

/// <summary>
/// Facade over Supabase REST + Auth + Storage APIs. Provides caching of
/// lookups (roles, stylists, services, payments, profiles) and hydration
/// of navigation properties before returning models to controllers.
/// </summary>
public class SupabaseService
{
    // Storage bucket names; all three resolve to the same underlying bucket.
    private const string GalleryBucket = "catalog-images";
    private const string CatalogImagesBucket = "catalog-images";
    private const string ProfilePhotoBucket = "catalog-images";
    // How many days ahead to generate stylist schedules.
    private const int ScheduleDays = 56;
    // How many days of schedule to read for weekly views.
    private const int ScheduleReadDays = 14;

    private static readonly string[] Days =
        { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" };

    // snake_case on the wire, case-insensitive on deserialise.
    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        PropertyNameCaseInsensitive = true
    };

    private const string DefaultAboutUs =
        "Cutting Edge is a premium salon based in Bloemfontein, offering expert haircuts, colouring, and grooming services since 2015. Our vision, your style.";

    private readonly HttpClient _http;
    private readonly IConfiguration _config;
    private readonly IHttpContextAccessor _ctx;

    // In-memory caches; cleared via Invalidate() whenever data changes.
    private List<RoleRow>? _roles;
    private List<Stylist>? _stylists;
    private List<Service>? _services;
    private List<PaymentMethod>? _payments;
    private readonly Dictionary<Guid, Profile> _profiles = new();

    public SupabaseService(IHttpClientFactory httpFactory, IConfiguration config, IHttpContextAccessor ctx)
    {
        _http = httpFactory.CreateClient();
        _config = config;
        _ctx = ctx;
    }

    // =====================================================================
    //  LOW-LEVEL HTTP HELPERS
    // =====================================================================
    /// <summary>Base Supabase URL; throws when unset/placeholder.</summary>
    private string BaseUrl
    {
        get
        {
            var url = (_config["Supabase:Url"] ?? "").Trim().TrimEnd('/');
            if (url.Length == 0 || url.Contains("your-project-id"))
                throw new InvalidOperationException(
                    "Supabase isn't configured yet. Set Supabase:Url, Supabase:AnonKey and Supabase:ServiceRoleKey.");
            return url;
        }
    }

    /// <summary>Public anon key; used for auth endpoints.</summary>
    private string AnonKey
    {
        get
        {
            var key = (_config["Supabase:AnonKey"] ?? "").Trim();
            if (key.Length == 0 || key.StartsWith("your-"))
                throw new InvalidOperationException("Supabase:AnonKey is not configured.");
            return key;
        }
    }

    /// <summary>Service-role key; used for privileged table/admin calls. Never expose to browsers.</summary>
    private string DbKey
    {
        get
        {
            var key = (_config["Supabase:ServiceRoleKey"] ?? "").Trim();
            if (key.Length == 0 || key.StartsWith("your-"))
                throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");
            return key;
        }
    }

    /// <summary>
    /// Builds a request to a Supabase path. Adds the apikey header and, unless
    /// using a new-style "sb_publishable_"/"sb_secret_" key, a Bearer token.
    /// </summary>
    private HttpRequestMessage Req(HttpMethod method, string path, string key, object? body = null, string? prefer = null)
    {
        var req = new HttpRequestMessage(method, BaseUrl + path);
        req.Headers.TryAddWithoutValidation("apikey", key);
        if (!key.StartsWith("sb_publishable_", StringComparison.Ordinal) &&
            !key.StartsWith("sb_secret_", StringComparison.Ordinal))
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
        if (prefer != null) req.Headers.TryAddWithoutValidation("Prefer", prefer);
        if (body != null)
            req.Content = new StringContent(JsonSerializer.Serialize(body, Json), Encoding.UTF8, "application/json");
        return req;
    }

    private async Task<string> SendAsync(HttpRequestMessage req)
    {
        using var resp = await _http.SendAsync(req);
        var text = await resp.Content.ReadAsStringAsync();
        if (!resp.IsSuccessStatusCode) throw MakeError(text, resp.StatusCode);
        return text;
    }

    /// <summary>
    /// Normalises Supabase/PostgREST error responses into a SupabaseException
    /// with a user-friendly message for known Postgres error codes.
    /// </summary>
    private static SupabaseException MakeError(string body, HttpStatusCode status)
    {
        string? code = null, msg = null;
        if (!string.IsNullOrWhiteSpace(body))
        {
            try
            {
                if (JsonNode.Parse(body) is JsonObject o)
                {
                    code = (o["code"] ?? o["error_code"])?.ToString();
                    msg = (o["message"] ?? o["msg"] ?? o["error_description"] ?? o["error"])?.ToString();
                }
            }
            catch (JsonException) { }
        }

        msg ??= string.IsNullOrWhiteSpace(body) ? status.ToString() : body;

        // Map a few well-known Postgres error codes to readable messages.
        if (code == "23503")
            msg = "This record is still linked to other data, so it can't be removed. Mark it inactive instead.";
        else if (code == "23505" && msg.Contains("uq_bookings_one_active_per_customer"))
            msg = "This customer already has an active booking.";
        else if (code == "23505")
            msg = "That value already exists (" + msg + ").";
        else if (code == "PGRST205" || code == "42P01")
            msg = "A table the portal needs doesn't exist in Supabase yet. (" + msg + ")";
        else if (code == "42703" || code == "PGRST204")
            msg = "A column the portal needs doesn't exist in Supabase yet. (" + msg + ")";

        return new SupabaseException(msg, status, code);
    }

    /// <summary>Detects "table not found" so callers can fall back gracefully.</summary>
    private static bool IsMissingTable(SupabaseException ex) =>
        ex.Code is "PGRST205" or "42P01" || ex.Status == HttpStatusCode.NotFound;

    private static string RestPath(string table, string query) =>
        "/rest/v1/" + table + (string.IsNullOrEmpty(query) ? "" : "?" + query);

    // --- Generic PostgREST helpers ------------------------------------------------

    private async Task<List<T>> SelectAsync<T>(string table, string query = "")
    {
        var text = await SendAsync(Req(HttpMethod.Get, RestPath(table, query), DbKey));
        return JsonSerializer.Deserialize<List<T>>(text, Json) ?? new List<T>();
    }

    private async Task<T?> SelectOneAsync<T>(string table, string query) where T : class =>
        (await SelectAsync<T>(table, query + "&limit=1")).FirstOrDefault();

    private async Task InsertAsync(string table, object body) =>
        await SendAsync(Req(HttpMethod.Post, RestPath(table, ""), DbKey, body, "return=minimal"));

    private async Task InsertManyAsync(string table, IEnumerable<object> rows)
    {
        var list = rows.ToList();
        if (list.Count == 0) return;
        await SendAsync(Req(HttpMethod.Post, RestPath(table, ""), DbKey, list, "return=minimal"));
    }

    private async Task<T> InsertReturningAsync<T>(string table, object body)
    {
        var text = await SendAsync(Req(HttpMethod.Post, RestPath(table, ""), DbKey, body, "return=representation"));
        var list = JsonSerializer.Deserialize<List<T>>(text, Json);
        if (list == null || list.Count == 0) throw new InvalidOperationException("Supabase didn't return the saved row.");
        return list[0];
    }

    private async Task UpsertAsync(string table, string onConflict, object body) =>
        await SendAsync(Req(HttpMethod.Post, RestPath(table, "on_conflict=" + onConflict), DbKey, body,
            "resolution=merge-duplicates,return=minimal"));

    private async Task PatchAsync(string table, string filter, object body) =>
        await SendAsync(Req(HttpMethod.Patch, RestPath(table, filter), DbKey, body, "return=minimal"));

    private async Task DeleteAsync(string table, string filter) =>
        await SendAsync(Req(HttpMethod.Delete, RestPath(table, filter), DbKey, null, "return=minimal"));

    // --- Formatting helpers -------------------------------------------------------

    private static string DateStr(DateTime d) => d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    private static string TimeStr(TimeSpan t) => t.ToString(@"hh\:mm\:ss", CultureInfo.InvariantCulture);
    private static string Q(string s) => Uri.EscapeDataString(s);

    private static string InList<TItem>(IEnumerable<TItem> items) =>
        "(" + string.Join(",", items.Select(i => Convert.ToString(i, CultureInfo.InvariantCulture))) + ")";

    // Builds an escaped ISO-8601 timestamp in local time for range filters.
    private static string Iso(DateTime localTime) =>
        Uri.EscapeDataString(new DateTimeOffset(DateTime.SpecifyKind(localTime, DateTimeKind.Local)).ToString("o"));

    /// <summary>Maps DB booking status to app-friendly status.</summary>
    private static string ToAppStatus(string? dbStatus)
    {
        if (string.Equals(dbStatus, "completed", StringComparison.OrdinalIgnoreCase)) return "Completed";
        if (string.Equals(dbStatus, "cancelled", StringComparison.OrdinalIgnoreCase)) return "Cancelled";
        return "Incomplete";
    }

    /// <summary>Maps app-friendly status back to DB status.</summary>
    private static string ToDbStatus(string? appStatus)
    {
        if (string.Equals(appStatus, "Completed", StringComparison.OrdinalIgnoreCase)) return "completed";
        if (string.Equals(appStatus, "Cancelled", StringComparison.OrdinalIgnoreCase)) return "cancelled";
        return "confirmed";
    }

    // =====================================================================
    //  LOOKUPS
    // =====================================================================
    private class RoleRow
    {
        public long RoleId { get; set; }
        public string RoleName { get; set; } = "";
    }

    private class ProfileRow
    {
        public Guid Id { get; set; }
        public string? FullName { get; set; }
        public string? Email { get; set; }
        public string? Phone { get; set; }
        public long? RoleId { get; set; }
        public string? PhotoUrl { get; set; }
        public string? Branch { get; set; }
        public DateTime? CreatedAt { get; set; }
    }

    // Cached list of roles; loaded on first access.
    private async Task<List<RoleRow>> RolesAsync() =>
        _roles ??= await SelectAsync<RoleRow>("roles", "select=role_id,role_name");

    // Looks up a role_id by role name; throws if the role is missing.
    private async Task<long> RoleIdAsync(string roleName)
    {
        var role = (await RolesAsync()).FirstOrDefault(r => r.RoleName.Equals(roleName, StringComparison.OrdinalIgnoreCase));
        return role?.RoleId ?? throw new InvalidOperationException($"The '{roleName}' role is missing from the roles table.");
    }

    // Maps a DB ProfileRow + role list to a Profile model.
    private static Profile ToProfile(ProfileRow r, List<RoleRow> roles) => new()
    {
        Id = r.Id,
        FullName = r.FullName ?? "",
        Email = r.Email ?? "",
        Phone = r.Phone,
        Role = roles.FirstOrDefault(x => x.RoleId == r.RoleId)?.RoleName ?? "Customer",
        PhotoUrl = r.PhotoUrl,
        Branch = r.Branch,
        CreatedAt = r.CreatedAt ?? DateTime.MinValue
    };

    /// <summary>
    /// Ensures the given profile IDs are cached and returns the full cache.
    /// Fetches in chunks of 50 to keep URLs short.
    /// </summary>
    private async Task<Dictionary<Guid, Profile>> ProfilesAsync(IEnumerable<Guid> ids)
    {
        var missing = ids.Distinct().Where(i => !_profiles.ContainsKey(i)).ToList();
        if (missing.Count > 0)
        {
            var roles = await RolesAsync();
            foreach (var chunk in missing.Chunk(50))
            {
                var rows = await SelectAsync<ProfileRow>("profiles",
                    $"select=id,full_name,email,phone,role_id,photo_url,branch,created_at&id=in.{InList(chunk)}");
                foreach (var r in rows) _profiles[r.Id] = ToProfile(r, roles);
            }
        }
        return _profiles;
    }

    // Cached list of stylists with their Profile navigation property populated.
    private async Task<List<Stylist>> StylistsAsync()
    {
        if (_stylists != null) return _stylists;
        var list = await SelectAsync<Stylist>("stylists", "select=*&order=stylist_id");
        var profiles = await ProfilesAsync(list.Select(s => s.ProfileId));
        foreach (var s in list) s.Profile = profiles.GetValueOrDefault(s.ProfileId);
        return _stylists = list;
    }

    // Cached list of services, alphabetically ordered.
    private async Task<List<Service>> ServicesAsync() =>
        _services ??= await SelectAsync<Service>("services", "select=*&order=name");

    // Cached list of payment methods.
    private async Task<List<PaymentMethod>> PaymentsAsync() =>
        _payments ??= await SelectAsync<PaymentMethod>("payment_methods", "select=*");

    // Drops all caches; call after any write that could affect lookups.
    private void Invalidate()
    {
        _stylists = null;
        _services = null;
        _payments = null;
        _profiles.Clear();
    }

    /// <summary>Populates navigation properties on bookings and normalises status.</summary>
    private async Task HydrateAsync(List<Booking> bookings)
    {
        if (bookings.Count == 0) return;
        var profiles = await ProfilesAsync(bookings.Select(b => b.CustomerId));
        var stylists = await StylistsAsync();
        var services = await ServicesAsync();
        var payments = await PaymentsAsync();

        foreach (var b in bookings)
        {
            b.Status = ToAppStatus(b.Status);
            b.Customer = profiles.GetValueOrDefault(b.CustomerId);
            b.Stylist = stylists.FirstOrDefault(s => s.StylistId == b.StylistId);
            b.Service = services.FirstOrDefault(s => s.ServiceId == b.ServiceId);
            b.PaymentMethod = payments.FirstOrDefault(p => p.PaymentMethodId == b.PaymentMethodId);
        }
    }

    /// <summary>Populates navigation properties on reviews (customer, stylist, booking).</summary>
    private async Task HydrateAsync(List<Review> reviews)
    {
        if (reviews.Count == 0) return;
        var profiles = await ProfilesAsync(reviews.Select(r => r.CustomerId));
        var stylists = await StylistsAsync();

        // Reviews reference bookings; load them in chunks and hydrate those too.
        var bookings = new List<Booking>();
        foreach (var chunk in reviews.Select(r => r.BookingId).Distinct().Chunk(50))
            bookings.AddRange(await SelectAsync<Booking>("bookings", $"select=*&booking_id=in.{InList(chunk)}"));
        await HydrateAsync(bookings);

        foreach (var r in reviews)
        {
            r.Customer = profiles.GetValueOrDefault(r.CustomerId);
            r.Stylist = stylists.FirstOrDefault(s => s.StylistId == r.StylistId);
            r.Booking = bookings.FirstOrDefault(b => b.BookingId == r.BookingId);
        }
    }

    /// <summary>Populates the Service navigation property on promotions.</summary>
    private async Task HydrateAsync(List<Promotion> promotions)
    {
        var services = await ServicesAsync();
        foreach (var p in promotions)
            p.Service = services.FirstOrDefault(s => s.ServiceId == p.ServiceId);
    }

    // Currently signed-in user's email from session, or null.
    private string? CurrentEmail => _ctx.HttpContext?.Session.GetString("UserEmail");

    /// <summary>
    /// Resolves the current user's Profile ID from session, falling back to a
    /// lookup by email when only the email is present.
    /// </summary>
    private async Task<Guid?> CurrentProfileIdAsync()
    {
        var idText = _ctx.HttpContext?.Session.GetString("UserId");
        if (Guid.TryParse(idText, out var id)) return id;

        var email = CurrentEmail;
        if (string.IsNullOrWhiteSpace(email)) return null;
        return (await GetProfileByEmailAsync(email))?.Id;
    }

    // =====================================================================
    //  AUTH
    // =====================================================================

    /// <summary>Signs in via Supabase GoTrue; returns null for bad credentials.</summary>
    public async Task<AuthSession?> SignInAsync(string email, string password)
    {
        var req = Req(HttpMethod.Post, "/auth/v1/token?grant_type=password", AnonKey, new { email = email.Trim(), password });
        using var resp = await _http.SendAsync(req);
        var text = await resp.Content.ReadAsStringAsync();

        if (resp.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.Unauthorized)
        {
            if (text.Contains("email_not_confirmed"))
                throw new InvalidOperationException("This email address hasn't been confirmed yet.");
            return null;
        }
        if (!resp.IsSuccessStatusCode) throw MakeError(text, resp.StatusCode);

        var node = JsonNode.Parse(text);
        var token = node?["access_token"]?.GetValue<string>();
        var userId = node?["user"]?["id"]?.GetValue<string>();
        var userEmail = node?["user"]?["email"]?.GetValue<string>();
        if (token == null || !Guid.TryParse(userId, out var id)) return null;

        return new AuthSession
        {
            AccessToken = token,
            User = new AuthUser { Id = id, Email = userEmail ?? email }
        };
    }

    // Auth is stateless server-side; cookie/session clearing is the controller's job.
    public Task SignOutAsync() => Task.CompletedTask;

    /// <summary>Requests Supabase's built-in password recovery email.</summary>
    public async Task SendPasswordRecoveryCodeAsync(string email)
    {
        using var req = Req(HttpMethod.Post, "/auth/v1/recover", AnonKey,
            new { email = email.Trim() });
        await SendAsync(req);
    }

    /// <summary>Secret used to HMAC manager recovery codes; must be ≥32 chars.</summary>
    private string ManagerRecoveryCodeSecret
    {
        get
        {
            var secret = _config["Email:RecoveryCodeSecret"];
            if (string.IsNullOrWhiteSpace(secret) || secret.Length < 32)
                throw new InvalidOperationException(
                    "Email:RecoveryCodeSecret must be a random secret of at least 32 characters " +
                    "configured in ASP.NET User Secrets or a server environment variable.");
            return secret;
        }
    }

    /// <summary>
    /// Validates that Supabase + SMTP + recovery secret are configured. Called
    /// early in the forgot-password flow so misconfigurations fail loudly.
    /// </summary>
    public void EnsureManagerRecoveryConfigured()
    {
        _ = DbKey;
        _ = ManagerRecoveryCodeSecret;

        var host = _config["Email:SmtpHost"]?.Trim();
        var user = _config["Email:SmtpUser"]?.Trim();
        var password = _config["Email:SmtpPass"];
        var fromEmail = _config["Email:FromEmail"]?.Trim();
        var portText = _config["Email:SmtpPort"];

        if (string.IsNullOrWhiteSpace(host) ||
            string.IsNullOrWhiteSpace(user) ||
            string.IsNullOrWhiteSpace(password) ||
            password.StartsWith("SET_", StringComparison.OrdinalIgnoreCase) ||
            password.StartsWith("your-", StringComparison.OrdinalIgnoreCase) ||
            string.IsNullOrWhiteSpace(fromEmail))
            throw new InvalidOperationException(
                "SMTP configuration is incomplete. Set Email:SmtpHost, SmtpPort, " +
                "SmtpUser, SmtpPass and FromEmail in server configuration.");

        if (!int.TryParse(portText, out var port) || port < 1 || port > 65535)
            throw new InvalidOperationException(
                "Email:SmtpPort must be a valid SMTP port number (587 is common for STARTTLS).");

        if (port == 465)
            throw new InvalidOperationException(
                "SMTP port 465 uses implicit TLS, which System.Net.Mail.SmtpClient " +
                "does not support. Use your provider's STARTTLS port (normally 587).");

        try
        {
            _ = new MailAddress(user);
            _ = new MailAddress(fromEmail);
        }
        catch (FormatException ex)
        {
            throw new InvalidOperationException(
                "Email:SmtpUser or Email:FromEmail has an invalid email address.", ex);
        }
    }

    /// <summary>Computes the HMAC-SHA256 of a recovery code bound to a manager ID.</summary>
    private string ManagerRecoveryCodeHmac(Guid managerId, string code)
    {
        var message = Encoding.UTF8.GetBytes($"cutting-edge-manager-recovery:v1:{managerId:D}:{code}");
        var secret = Encoding.UTF8.GetBytes(ManagerRecoveryCodeSecret);
        return Convert.ToHexString(HMACSHA256.HashData(secret, message)).ToLowerInvariant();
    }

    /// <summary>
    /// Generates a six-digit recovery code, stores its HMAC in Supabase via RPC,
    /// and emails the plaintext code to the manager. If the email fails, the
    /// stored code is cancelled so it can't be used.
    /// </summary>
    public async Task SendManagerPasswordRecoveryEmailAsync(Guid managerId, string requestedEmail)
    {
        EnsureManagerRecoveryConfigured();
        var profile = await GetProfileByIdAsync(managerId);
        var authEmail = await GetAuthUserEmailAsync(managerId);
        // Verify the requested email matches both profile and Supabase Auth.
        if (profile == null ||
            !string.Equals(profile.Role, "Manager", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(profile.Email, requestedEmail.Trim(), StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(authEmail, profile.Email, StringComparison.OrdinalIgnoreCase))
            return;

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000)
            .ToString("D6", CultureInfo.InvariantCulture);
        var hmac = ManagerRecoveryCodeHmac(managerId, code);
        var result = await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/ce_issue_manager_recovery_code", DbKey, new
            {
                p_manager_id = managerId,
                p_code_hmac = hmac
            }));

        if (!JsonSerializer.Deserialize<bool>(result, Json))
            return;

        // Inline HTML body; brand-consistent and self-contained.
        var html = $"""
            <!doctype html>
            <html><body style="margin:0;padding:28px 12px;background:#f4f4f4;font-family:Arial,sans-serif;">
              <div style="max-width:520px;margin:auto;background:#111;border:1px solid #d4af37;border-radius:12px;padding:28px;text-align:center;">
                <h1 style="color:#d4af37">CUTTING EDGE</h1>
                <p style="color:#eee">Manager password reset</p>
                <p style="color:#ddd">Enter this six-digit code in the manager portal to set a new password.</p>
                <p style="padding:18px;background:#202020;border:1px solid #d4af37;border-radius:8px;color:#f4b400;font-size:32px;letter-spacing:6px;font-weight:bold">{code}</p>
                <p style="color:#ddd">This code expires in 10 minutes and can be used only once.</p>
                <p style="color:#ff9b9b">If you did not request this reset, ignore the email. Never share this code.</p>
              </div>
            </body></html>
            """;

        try
        {
            await SendEmailAsync(authEmail!, "Cutting Edge Salon - Password Reset Code", html, isHtml: true);
        }
        catch
        {
            // Roll back the issued code if delivery fails so it can't be reused.
            try
            {
                await SendAsync(Req(HttpMethod.Post,
                    "/rest/v1/rpc/ce_cancel_manager_recovery_code", DbKey, new
                    {
                        p_manager_id = managerId,
                        p_code_hmac = hmac
                    }));
            }
            catch { }
            throw;
        }
    }

    /// <summary>
    /// Verifies an SMTP-issued recovery code (via HMAC comparison in SQL),
    /// then sets the new password via the admin API.
    /// </summary>
    public async Task VerifyManagerSmtpCodeAndSetPasswordAsync(
        string email, string code, string newPassword)
    {
        email = email?.Trim() ?? "";
        if (string.IsNullOrWhiteSpace(code) ||
            !System.Text.RegularExpressions.Regex.IsMatch(code, @"^[0-9]{6}$"))
            throw new InvalidOperationException("Invalid verification code.");
        if (string.IsNullOrWhiteSpace(newPassword) ||
            newPassword.Length is < 8 or > 128)
            throw new InvalidOperationException("Invalid password length.");

        var profile = await GetProfileByEmailAsync(email);
        if (profile == null ||
            !string.Equals(profile.Role, "Manager", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(profile.Email, email, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Invalid or expired verification code.");

        var authEmail = await GetAuthUserEmailAsync(profile.Id);
        if (!string.Equals(authEmail, profile.Email, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Invalid or expired verification code.");

        var result = await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/ce_consume_manager_recovery_code", DbKey, new
            {
                p_manager_id = profile.Id,
                p_code_hmac = ManagerRecoveryCodeHmac(profile.Id, code)
            }));
        if (!JsonSerializer.Deserialize<bool>(result, Json))
            throw new InvalidOperationException("Invalid, expired or already used verification code.");

        await AdminUpdateUserAsync(profile.Id, new { password = newPassword });
    }

    /// <summary>
    /// Legacy Supabase-native recovery: verifies the token with GoTrue, then
    /// uses the returned access token to set a new password.
    /// </summary>
    public async Task VerifyManagerRecoveryCodeAndSetPasswordAsync(
        string email, string code, string newPassword)
    {
        using var verifyReq = Req(HttpMethod.Post, "/auth/v1/verify", AnonKey,
            new { email = email.Trim(), token = code.Trim(), type = "recovery" });
        var json = await SendAsync(verifyReq);
        var result = JsonNode.Parse(json)
            ?? throw new InvalidOperationException("Verification response was empty.");

        var accessToken = result["access_token"]?.GetValue<string>();
        var authIdText = result["user"]?["id"]?.GetValue<string>();
        var verifiedEmail = result["user"]?["email"]?.GetValue<string>();

        if (string.IsNullOrWhiteSpace(accessToken) ||
            !Guid.TryParse(authIdText, out var authId) ||
            !string.Equals(email.Trim(), verifiedEmail, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Recovery code verification failed.");

        var manager = await GetProfileByIdAsync(authId);
        if (manager == null ||
            !string.Equals(manager.Role, "Manager", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(manager.Email, verifiedEmail, StringComparison.OrdinalIgnoreCase))
            throw new UnauthorizedAccessException("This account is not a linked manager account.");

        using var changeReq = new HttpRequestMessage(HttpMethod.Put,
            BaseUrl + "/auth/v1/user");
        changeReq.Headers.TryAddWithoutValidation("apikey", AnonKey);
        changeReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        changeReq.Content = new StringContent(
            JsonSerializer.Serialize(new { password = newPassword }, Json),
            Encoding.UTF8, "application/json");
        await SendAsync(changeReq);
    }

    /// <summary>Uses a Supabase invite/reset token directly to set a password.</summary>
    public async Task ResetPasswordAsync(string token, string newPassword)
    {
        if (string.IsNullOrWhiteSpace(token))
            throw new InvalidOperationException("This reset link is missing its token.");

        var req = new HttpRequestMessage(HttpMethod.Put, BaseUrl + "/auth/v1/user");
        req.Headers.TryAddWithoutValidation("apikey", AnonKey);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        req.Content = new StringContent(JsonSerializer.Serialize(new { password = newPassword }, Json), Encoding.UTF8, "application/json");
        await SendAsync(req);
    }

    /// <summary>
    /// Changes the signed-in manager's password: re-authenticates with the
    /// current password, then calls GoTrue with the fresh session token.
    /// </summary>
    public async Task ChangePasswordAsync(string currentPassword, string newPassword)
    {
        var expectedId = await CurrentProfileIdAsync()
            ?? throw new InvalidOperationException("Your manager profile isn't linked to Supabase Auth.");
        var profile = await GetProfileByIdAsync(expectedId)
            ?? throw new InvalidOperationException("Your manager profile could not be loaded.");
        if (!string.Equals(profile.Role, "Manager", StringComparison.OrdinalIgnoreCase))
            throw new UnauthorizedAccessException("Only a manager can change their password here.");

        // Re-authenticate to prove possession of the current password.
        var session = await SignInAsync(profile.Email, currentPassword);
        if (session?.User == null || session.User.Id != expectedId ||
            string.IsNullOrWhiteSpace(session.AccessToken))
            throw new InvalidOperationException("Your current Supabase password or account link is incorrect.");

        using var req = new HttpRequestMessage(HttpMethod.Put, BaseUrl + "/auth/v1/user");
        req.Headers.TryAddWithoutValidation("apikey", AnonKey);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);
        req.Content = new StringContent(
            JsonSerializer.Serialize(new { password = newPassword }, Json),
            Encoding.UTF8, "application/json");
        await SendAsync(req);
    }

    // Admin API helper for updating auth users (e.g. set password/email).
    private async Task AdminUpdateUserAsync(Guid userId, object attributes) =>
        await SendAsync(Req(HttpMethod.Put, $"/auth/v1/admin/users/{userId}", DbKey, attributes));

    /// <summary>
    /// Sends a Supabase-style invitation email to a stylist and returns the
    /// created auth user ID. Redirect URL must be HTTPS (or localhost in dev).
    /// </summary>
    private async Task<Guid> InviteStylistAsync(string email, string fullName)
    {
        // Prefer configured redirect; otherwise derive from the current request.
        var configuredRedirect = _config["Supabase:StylistInviteRedirectUrl"];
        string redirect;
        if (!string.IsNullOrWhiteSpace(configuredRedirect))
        {
            redirect = configuredRedirect.Trim();
        }
        else
        {
            var request = _ctx.HttpContext?.Request;
            if (request == null)
                throw new InvalidOperationException(
                    "Configure Supabase:StylistInviteRedirectUrl for stylist invitations.");
            redirect = $"{request.Scheme}://{request.Host}{request.PathBase}/Account/AcceptStylistInvite";
        }

        if (!Uri.TryCreate(redirect, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttps &&
             !(uri.Scheme == Uri.UriSchemeHttp && uri.IsLoopback)))
            throw new InvalidOperationException(
                "The stylist invitation redirect must be an HTTPS URL (or localhost during development).");

        var result = await SendAsync(Req(HttpMethod.Post,
            "/auth/v1/invite?redirect_to=" + Q(redirect), DbKey,
            new { email = email.Trim(), data = new { full_name = fullName.Trim() } }));
        var id = JsonNode.Parse(result)?["id"]?.GetValue<string>();
        return Guid.TryParse(id, out var userId)
            ? userId
            : throw new InvalidOperationException("Supabase did not return the invited stylist's user ID.");
    }

    /// <summary>Creates a stylist auth user with an initial password (email pre-confirmed).</summary>
    private async Task<Guid> CreateStylistAuthUserAsync(string email, string fullName, string password)
    {
        email = email.Trim();
        fullName = fullName.Trim();
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(fullName))
            throw new InvalidOperationException("A name and email are required for the stylist account.");
        if (string.IsNullOrWhiteSpace(password) || password.Length < 8)
            throw new InvalidOperationException("The stylist's initial password must contain at least 8 characters.");

        var response = await SendAsync(Req(HttpMethod.Post, "/auth/v1/admin/users", DbKey,
            new
            {
                email,
                password,
                email_confirm = true,
                user_metadata = new { full_name = fullName }
            }));

        var id = JsonNode.Parse(response)?["id"]?.GetValue<string>();
        return Guid.TryParse(id, out var userId)
            ? userId
            : throw new InvalidOperationException("Supabase didn't return the created stylist's user ID.");
    }

    // Deletes a Supabase auth user (used when stylist creation rolls back).
    private async Task AdminDeleteUserAsync(Guid userId) =>
        await SendAsync(Req(HttpMethod.Delete, $"/auth/v1/admin/users/{userId}", DbKey));

    // =====================================================================
    //  E-MAIL
    // =====================================================================

    /// <summary>Sends a plain-text or HTML email via SMTP (STARTTLS only).</summary>
    public async Task SendEmailAsync(string to, string subject, string body, bool isHtml = false)
    {
        var host = _config["Email:SmtpHost"];
        var user = _config["Email:SmtpUser"];
        var pass = _config["Email:SmtpPass"];
        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(user) ||
            string.IsNullOrWhiteSpace(pass) || pass.StartsWith("your-"))
            throw new InvalidOperationException(
                "E-mail isn't set up yet. Add Email:SmtpUser and Email:SmtpPass to your configuration.");

        var port = int.TryParse(_config["Email:SmtpPort"], out var p) ? p : 587;
        if (port == 465)
            throw new InvalidOperationException(
                "This SMTP client requires STARTTLS, not implicit TLS on port 465. " +
                "Use the provider's STARTTLS port, commonly 587.");
        if (port < 1 || port > 65535)
            throw new InvalidOperationException("Invalid Email:SmtpPort configuration.");

        try
        {
            var from = new MailAddress(_config["Email:FromEmail"] ?? user, _config["Email:FromName"] ?? "Cutting Edge Salon");
            using var msg = new MailMessage(from, new MailAddress(to))
            {
                Subject = subject,
                Body = body,
                IsBodyHtml = isHtml
            };
            using var smtp = new SmtpClient(host, port)
            {
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false,
                EnableSsl = true,
                Credentials = new NetworkCredential(user.Trim(), pass),
                Timeout = 30000
            };
            await smtp.SendMailAsync(msg);
        }
        catch (FormatException)
        {
            throw new InvalidOperationException("One of the e-mail addresses isn't valid.");
        }
    }

    // =====================================================================
    //  DASHBOARD
    // =====================================================================

    /// <summary>Aggregates today's metrics: bookings, cancellations, estimated revenue, avg rating.</summary>
    public async Task<DashboardMetrics> GetDashboardMetricsAsync()
    {
        var today = DateTime.Today;

        var bookings = await SelectAsync<Booking>("bookings",
            $"select=booking_id,service_id,status&appointment_date=eq.{DateStr(today)}&status=neq.cancelled");

        var services = await ServicesAsync();

        var cancelled = await SelectAsync<Cancellation>("cancellations",
            $"select=cancellation_id&cancelled_at=gte.{Iso(today)}&cancelled_at=lt.{Iso(today.AddDays(1))}");

        double avgRating = 0;
        try
        {
            var reviews = await SelectAsync<Review>("reviews", "select=rating");
            if (reviews.Count > 0)
                avgRating = Math.Round(reviews.Average(r => r.Rating), 1);
        }
        catch (SupabaseException ex) when (IsMissingTable(ex))
        {
            // Tolerate missing reviews table; show 0 instead.
            avgRating = 0;
        }

        return new DashboardMetrics
        {
            TodayBookings = bookings.Count,
            Cancelled = cancelled.Count,
            EstimatedRevenue = bookings.Sum(b => services.FirstOrDefault(s => s.ServiceId == b.ServiceId)?.Price ?? 0),
            AverageRating = avgRating
        };
    }

    /// <summary>Returns today's non-cancelled bookings, hydrated for display.</summary>
    public async Task<List<Booking>> GetTodayBookingsAsync()
    {
        var list = await SelectAsync<Booking>("bookings",
            $"select=*&appointment_date=eq.{DateStr(DateTime.Today)}&status=neq.cancelled&order=start_time");
        await HydrateAsync(list);
        return list;
    }

    /// <summary>Returns the newest <paramref name="count"/> reviews (or empty if missing table).</summary>
    public async Task<List<Review>> GetRecentReviewsAsync(int count)
    {
        try
        {
            var list = await SelectAsync<Review>("reviews", $"select=*&order=created_at.desc&limit={count}");
            await HydrateAsync(list);
            return list;
        }
        catch (SupabaseException ex) when (IsMissingTable(ex))
        {
            return new List<Review>();
        }
    }

    // =====================================================================
    //  BOOKINGS
    // =====================================================================

    /// <summary>Returns bookings filtered by status, date, and free-text search.</summary>
    public async Task<List<Booking>> GetFilteredBookingsAsync(string? status, string? date, string? search)
    {
        var filters = new List<string> { "select=*" };

        // Map friendly statuses to DB status filters.
        if (string.Equals(status, "Completed", StringComparison.OrdinalIgnoreCase)) filters.Add("status=eq.completed");
        else if (string.Equals(status, "Incomplete", StringComparison.OrdinalIgnoreCase)) filters.Add("status=in.(pending,confirmed,booked,incomplete)");
        else if (string.Equals(status, "Cancelled", StringComparison.OrdinalIgnoreCase)) filters.Add("status=eq.cancelled");

        if (DateTime.TryParse(date, out var d)) filters.Add($"appointment_date=eq.{DateStr(d)}");

        filters.Add("order=appointment_date.desc,start_time.asc");
        filters.Add("limit=1000");

        var list = await SelectAsync<Booking>("bookings", string.Join("&", filters));
        await HydrateAsync(list);
        await HydrateCancellationsAsync(list);

        // Search runs client-side because it spans joined fields.
        if (!string.IsNullOrWhiteSpace(search))
            list = list.Where(b =>
                (b.Customer?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (b.Service?.Name ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (b.Stylist?.Profile?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase)).ToList();

        return list;
    }

    /// <summary>Returns a single hydrated booking with cancellation info, or null.</summary>
    public async Task<Booking?> GetBookingByIdAsync(long id)
    {
        var b = await SelectOneAsync<Booking>("bookings", $"select=*&booking_id=eq.{id}");
        if (b == null) return null;
        await HydrateAsync(new List<Booking> { b });
        await HydrateCancellationsAsync(new List<Booking> { b });
        return b;
    }

    /// <summary>Populates Cancellation navigation for any cancelled bookings.</summary>
    private async Task HydrateCancellationsAsync(List<Booking> bookings)
    {
        var cancelled = bookings.Where(b => b.Status == "Cancelled").ToList();
        if (cancelled.Count == 0) return;

        var records = new List<Cancellation>();
        foreach (var ids in cancelled.Select(b => b.BookingId).Distinct().Chunk(75))
            records.AddRange(await SelectAsync<Cancellation>("cancellations",
                $"select=*&booking_id=in.{InList(ids)}&order=cancelled_at.desc"));

        // Resolve actor details from Profile when CancelledBy is a UUID.
        var actors = records
            .Select(r => Guid.TryParse(r.CancelledBy, out var id) ? id : Guid.Empty)
            .Where(id => id != Guid.Empty).Distinct().ToList();
        var actorProfiles = await ProfilesAsync(actors);

        foreach (var booking in cancelled)
        {
            var record = records.FirstOrDefault(r => r.BookingId == booking.BookingId);
            booking.Cancellation = record;
            if (record == null) continue;

            if (Guid.TryParse(record.CancelledBy, out var actorId) &&
                actorProfiles.TryGetValue(actorId, out var profile))
            {
                if (string.IsNullOrWhiteSpace(record.CancelledActor))
                    record.CancelledActor = profile.Role;
                if (string.IsNullOrWhiteSpace(record.CancelledByName))
                    record.CancelledByName = profile.FullName;
            }
            else if (string.IsNullOrWhiteSpace(record.CancelledActor) &&
                     !string.IsNullOrWhiteSpace(record.CancelledBy) &&
                     !Guid.TryParse(record.CancelledBy, out _))
            {
                // Legacy rows store a plain actor label rather than a UUID.
                record.CancelledActor = record.CancelledBy;
            }
        }
    }

    /// <summary>Transitions an active booking to "completed".</summary>
    public async Task UpdateBookingStatusAsync(long id, string status)
    {
        var current = await GetBookingByIdAsync(id)
            ?? throw new InvalidOperationException("Booking not found.");
        if (current.Status is "Completed" or "Cancelled")
            throw new InvalidOperationException("A completed or cancelled booking cannot change status.");
        if (status != "Completed")
            throw new InvalidOperationException("Use the cancellation action to cancel bookings with a reason.");
        // Conditional PATCH: only succeeds if the row is still in an active status.
        var completed = await SendAsync(Req(HttpMethod.Patch,
            RestPath("bookings", $"booking_id=eq.{id}&status=in.(pending,confirmed,booked,incomplete)"),
            DbKey, new { status = "completed" }, "return=representation"));
        if ((JsonNode.Parse(completed) as JsonArray)?.Count != 1)
            throw new InvalidOperationException("Booking has already been completed or cancelled.");
    }

    /// <summary>Invokes the SQL routine that cancels overdue confirmed bookings.</summary>
    public async Task ExpireOverdueBookingsAsync()
    {
        await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/expire_overdue_bookings", DbKey, new { }));
    }

    /// <summary>
    /// Manager-initiated cancellation. Requires a reason (≤1000 chars), calls
    /// the cancel RPC, then notifies customer & stylist (best-effort).
    /// </summary>
    public async Task CancelBookingByManagerAsync(long id, string reason, string? managerName = null)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new InvalidOperationException("Please enter a cancellation reason.");
        if (reason.Trim().Length > 1000)
            throw new InvalidOperationException("The cancellation reason must be 1000 characters or fewer.");
        var booking = await GetBookingByIdAsync(id)
            ?? throw new InvalidOperationException("Booking not found.");
        if (booking.Status is "Completed" or "Cancelled")
            throw new InvalidOperationException("This booking can no longer be cancelled.");

        await SendAsync(Req(HttpMethod.Post, "/rest/v1/rpc/cancel_booking_by_manager",
            DbKey, new
            {
                p_booking_id = id,
                p_reason = reason.Trim(),
                p_manager_name = string.IsNullOrWhiteSpace(managerName) ? "Manager" : managerName.Trim()
            }));
        // Notifications are best-effort; cancellation itself has already succeeded.
        try
        {
            await CreateNotificationAsync(booking.CustomerId, "Booking cancelled",
                $"The salon cancelled your appointment. Reason: {reason.Trim()}", "Booking");
            if (booking.Stylist != null)
                await CreateNotificationAsync(booking.Stylist.ProfileId, "Appointment cancelled",
                    $"A booking on {booking.AppointmentDate:dd MMM yyyy} was cancelled by the manager. Reason: {reason.Trim()}", "Booking");
        }
        catch { }
    }

    /// <summary>
    /// Reschedules an active booking. Recomputes end time from the service's
    /// duration and rejects same-day or past slots.
    /// </summary>
    public async Task<TimeSpan> RescheduleBookingAsync(long id, DateTime date, TimeSpan start)
    {
        var booking = await GetBookingByIdAsync(id)
            ?? throw new InvalidOperationException("Booking not found.");
        if (booking.Status is "Completed" or "Cancelled")
            throw new InvalidOperationException("This booking cannot be rescheduled.");
        var minutes = booking.Service?.DurationMinutes ?? 0;
        if (minutes <= 0 || minutes >= 1440)
            throw new InvalidOperationException("Set a valid duration for this service before rescheduling.");
        var end = start.Add(TimeSpan.FromMinutes(minutes));
        if (end >= TimeSpan.FromDays(1))
            throw new InvalidOperationException("The appointment must finish on the same date.");
        // At least 2 hours into the future (SA time assumed).
        if (date.Date.Add(start) <= DateTime.UtcNow.AddHours(2))
            throw new InvalidOperationException("Choose a future date and start time (South African time).");

        await SendAsync(Req(HttpMethod.Post, "/rest/v1/rpc/manager_reschedule_booking",
            DbKey, new
            {
                p_booking_id = id,
                p_appointment_date = DateStr(date),
                p_start_time = TimeStr(start)
            }));
        return end;
    }

    /// <summary>Inserts a notification row for the given profile.</summary>
    public async Task CreateNotificationAsync(Guid profileId, string title, string message, string? type = null) =>
        await InsertAsync("notifications", new
        {
            profile_id = profileId,
            title,
            message,
            notification_type = type,
            is_read = false
        });

    /// <summary>Upserts a cancellation record keyed on booking_id.</summary>
    public async Task CreateCancellationRecordAsync(long bookingId, string reason) =>
        await UpsertAsync("cancellations", "booking_id", new { booking_id = bookingId, reason });

    /// <summary>
    /// Updates editable booking fields (notes/status). Reschedules first if the
    /// date/time changed, and preserves the original status when unchanged.
    /// </summary>
    public async Task UpdateBookingAsync(Booking booking)
    {
        var current = await SelectOneAsync<Booking>("bookings", $"select=booking_id,status,appointment_date,start_time,end_time&booking_id=eq.{booking.BookingId}");
        if (current?.Status is "completed" or "cancelled")
            throw new InvalidOperationException("Completed and cancelled bookings cannot be rescheduled or edited.");
        var dbStatus = ToDbStatus(booking.Status);
        // Preserve specific active statuses (pending/confirmed/etc.) rather than collapsing to "confirmed".
        if (dbStatus == "confirmed" && current != null &&
            (current.Status == "pending" || current.Status == "confirmed" ||
             current.Status == "booked" || current.Status == "incomplete"))
            dbStatus = current.Status;

        if (booking.AppointmentDate.Date != current?.AppointmentDate.Date ||
            booking.StartTime != current?.StartTime)
        {
            await RescheduleBookingAsync(booking.BookingId, booking.AppointmentDate,
                booking.StartTime);
        }
        await PatchAsync("bookings", $"booking_id=eq.{booking.BookingId}", new
        {
            status = dbStatus,
            additional_notes = booking.AdditionalNotes
        });
    }

    // Bookings are never hard-deleted; "delete" means "cancel".
    public Task DeleteBookingAsync(long id, string reason) =>
        CancelBookingByManagerAsync(id, reason);

    // =====================================================================
    //  STYLISTS
    // =====================================================================
    /// <summary>All stylists with populated profiles, active first, then by name.</summary>
    public async Task<List<Stylist>> GetAllStylistsWithProfilesAsync() =>
        (await StylistsAsync()).OrderByDescending(s => s.Active).ThenBy(s => s.Profile?.FullName).ToList();

    public async Task<Stylist?> GetStylistByIdAsync(long id) =>
        (await StylistsAsync()).FirstOrDefault(s => s.StylistId == id);

    // Row shape from stylist_services join table.
    private class StylistServiceRow
    {
        public long StylistId { get; set; }
        public long ServiceId { get; set; }
    }

    /// <summary>Services assigned to a stylist, sorted by name.</summary>
    public async Task<List<Service>> GetServicesForStylistAsync(long stylistId)
    {
        var assignments = await SelectAsync<StylistServiceRow>("stylist_services",
            $"select=stylist_id,service_id&stylist_id=eq.{stylistId}");
        if (assignments.Count == 0) return new List<Service>();
        var assignedIds = assignments.Select(x => x.ServiceId).ToHashSet();
        return (await ServicesAsync())
            .Where(s => assignedIds.Contains(s.ServiceId))
            .OrderBy(s => s.Name)
            .ToList();
    }

    public Task<List<Review>> GetReviewsForStylistAsync(long stylistId) =>
        GetFilteredReviewsAsync(null, stylistId, null, null);

    /// <summary>
    /// Builds a per-day availability calendar for a stylist, merging schedule
    /// shifts with blocked dates. Used by the stylist details page.
    /// </summary>
    public async Task<List<StylistAvailabilityDayViewModel>> GetStylistAvailabilityForDetailsAsync(
        long stylistId, int days = 28)
    {
        if (days < 1 || days > 56)
            throw new ArgumentOutOfRangeException(nameof(days));

        var first = DateTime.Today;
        var last = first.AddDays(days);

        var shifts = await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&stylist_id=eq.{stylistId}" +
            $"&work_date=gte.{DateStr(first)}&work_date=lt.{DateStr(last)}" +
            "&order=work_date,start_time");
        var blocked = await SelectAsync<BlockedDate>("blocked_dates",
            $"select=id,stylist_id,blocked_date,reason&stylist_id=eq.{stylistId}" +
            $"&blocked_date=gte.{DateStr(first)}&blocked_date=lt.{DateStr(last)}" +
            "&order=blocked_date");

        // Group per day so each calendar cell can be built in O(1).
        var shiftsByDate = shifts.GroupBy(x => x.WorkDate.Date)
            .ToDictionary(x => x.Key, x => x.ToList());
        var blockedByDate = blocked.GroupBy(x => x.Date.Date)
            .ToDictionary(x => x.Key, x => x.ToList());

        var calendar = new List<StylistAvailabilityDayViewModel>(days);
        for (var date = first; date < last; date = date.AddDays(1))
        {
            shiftsByDate.TryGetValue(date, out var dayShifts);
            blockedByDate.TryGetValue(date, out var dayBlocks);
            var workingShifts = dayShifts?.Where(x => x.IsAvailable).ToList();
            var reasons = dayBlocks?.Select(x => x.Reason?.Trim())
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            calendar.Add(new StylistAvailabilityDayViewModel
            {
                Date = date,
                HasShift = dayShifts is { Count: > 0 },
                IsAvailable = workingShifts is { Count: > 0 } && dayBlocks is not { Count: > 0 },
                IsBlocked = dayBlocks is { Count: > 0 },
                Reason = dayBlocks is { Count: > 0 }
                    ? (reasons is { Count: > 0 } ? string.Join("; ", reasons) : "No reason provided")
                    : dayShifts is { Count: > 0 } && workingShifts is not { Count: > 0 }
                        ? "Marked unavailable in schedule"
                        : null,
                Hours = workingShifts is { Count: > 0 }
                    ? string.Join(", ", workingShifts.Select(x =>
                        x.StartTime.ToString(@"hh\:mm") + "–" + x.EndTime.ToString(@"hh\:mm")))
                    : null
            });
        }
        return calendar;
    }

    /// <summary>
    /// Computes rating distribution + averages for a stylist, paginating through
    /// reviews 500 at a time to avoid row limits.
    /// </summary>
    public async Task<StylistRatingSummaryViewModel> GetStylistRatingSummaryAsync(long stylistId)
    {
        const int pageSize = 500;
        var summary = new StylistRatingSummaryViewModel();
        double ratingSum = 0;
        double serviceSum = 0;

        try
        {
            for (var offset = 0; ; offset += pageSize)
            {
                var page = await SelectAsync<Review>("reviews",
                    $"select=rating,service_rating&stylist_id=eq.{stylistId}" +
                    $"&order=created_at.desc&limit={pageSize}&offset={offset}");

                foreach (var review in page)
                {
                    if (review.Rating >= 1 && review.Rating <= 5)
                    {
                        summary.StarCounts[review.Rating]++;
                        summary.TotalReviews++;
                        ratingSum += review.Rating;
                        if (review.Rating <= 2) summary.LowRatingCount++;
                    }
                    if (review.ServiceRating is >= 1 and <= 5)
                    {
                        serviceSum += review.ServiceRating.Value;
                        summary.ServiceRatingCount++;
                    }
                }
                if (page.Count < pageSize) break;
            }
        }
        catch (SupabaseException ex) when (IsMissingTable(ex))
        {
            return summary;
        }

        summary.AverageStylistRating = summary.TotalReviews == 0
            ? 0 : Math.Round(ratingSum / summary.TotalReviews, 1);
        summary.AverageServiceRating = summary.ServiceRatingCount == 0
            ? null : Math.Round(serviceSum / summary.ServiceRatingCount, 1);
        return summary;
    }

    public Task<List<StylistSchedule>> GetUpcomingScheduleForStylistAsync(long stylistId) =>
        SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&stylist_id=eq.{stylistId}&is_available=eq.true" +
            $"&work_date=gte.{DateStr(DateTime.Today)}&order=work_date.asc,start_time.asc&limit=56");

    /// <summary>Produces a human-readable summary of enabled working days/hours.</summary>
    private static string WorkingHoursSummary(Dictionary<string, DaySchedule> week)
    {
        var on = Days.Where(d => week.TryGetValue(d, out var s) && s.Enabled).ToList();
        if (on.Count == 0) return "Not scheduled";
        var first = week[on[0]];
        return string.Join(", ", on.Select(d => d[..3])) + $" · {first.StartTime} – {first.EndTime}";
    }

    /// <summary>Builds the edit view model for a stylist (services + weekly schedule).</summary>
    public async Task<StylistViewModel?> GetStylistViewModelAsync(long id)
    {
        var s = await GetStylistByIdAsync(id);
        if (s == null) return null;

        var serviceIds = new List<long>();
        try
        {
            var rows = await SelectAsync<StylistServiceRow>("stylist_services", $"select=*&stylist_id=eq.{id}");
            serviceIds = rows.Select(r => r.ServiceId).ToList();
        }
        catch (SupabaseException ex) when (IsMissingTable(ex)) { }

        var schedule = await GetStylistScheduleAsync(id);

        return new StylistViewModel
        {
            StylistId = s.StylistId,
            ProfileId = s.ProfileId,
            FullName = s.Profile?.FullName ?? "",
            Email = s.Profile?.Email ?? "",
            Phone = s.Profile?.Phone,
            Role = "Stylist",
            Active = s.Active,
            PhotoUrl = s.Profile?.PhotoUrl ?? s.PhotoUrl,
            WorkingHours = schedule == null ? "Not scheduled" : WorkingHoursSummary(schedule.WeekSchedule),
            ServiceIds = serviceIds
        };
    }

    /// <summary>
    /// Creates a stylist: invite (or create with password) an auth user, insert
    /// profile + stylist, assign services, and seed a default schedule. If any
    /// step fails, the auth user is rolled back.
    /// </summary>
    public async Task CreateStylistAsync(StylistViewModel model)
    {
        var roleId = await RoleIdAsync("Stylist");
        if (string.IsNullOrWhiteSpace(model.Email) || string.IsNullOrWhiteSpace(model.FullName))
            throw new InvalidOperationException("A stylist name and email address are required.");

        var userId = string.IsNullOrWhiteSpace(model.InitialPassword)
            ? await InviteStylistAsync(model.Email, model.FullName)
            : await CreateStylistAuthUserAsync(model.Email, model.FullName, model.InitialPassword);

        try
        {
            await UpsertAsync("profiles", "id", new
            {
                id = userId,
                full_name = model.FullName,
                email = model.Email.Trim(),
                phone = model.Phone,
                role_id = roleId
            });

            var stylist = await InsertReturningAsync<Stylist>("stylists", new
            {
                profile_id = userId,
                active = model.Active
            });

            await SetStylistServicesAsync(stylist.StylistId, model.ServiceIds);
            await SaveWeekAsync(stylist.StylistId, DefaultWeek());
        }
        catch
        {
            // Roll back the auth user so the email address can be reused.
            try { await AdminDeleteUserAsync(userId); } catch { }
            throw;
        }
        finally
        {
            Invalidate();
        }
    }

    /// <summary>Updates a stylist profile: email, name, phone, active flag, services.</summary>
    public async Task UpdateStylistAsync(StylistViewModel model)
    {
        var stylist = await GetStylistByIdAsync(model.StylistId);
        if (stylist == null) return;

        var email = model.Email.Trim();
        // Sync auth email if the profile email was changed.
        if (stylist.Profile != null && !string.Equals(stylist.Profile.Email, email, StringComparison.OrdinalIgnoreCase))
            await AdminUpdateUserAsync(stylist.ProfileId, new { email, email_confirm = true });

        await PatchAsync("profiles", $"id=eq.{stylist.ProfileId}", new
        {
            full_name = model.FullName,
            email,
            phone = model.Phone
        });
        await PatchAsync("stylists", $"stylist_id=eq.{stylist.StylistId}", new { active = model.Active });
        await SetStylistServicesAsync(stylist.StylistId, model.ServiceIds);
        Invalidate();
    }

    /// <summary>
    /// Resets a stylist's password through the admin API after verifying the
    /// profile ↔ auth email linkage.
    /// </summary>
    public async Task ResetStylistPasswordAsync(long stylistId, string newPassword)
    {
        if (string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 8 || newPassword.Length > 128)
            throw new ArgumentException("Password must contain between 8 and 128 characters.", nameof(newPassword));

        var stylist = await GetStylistByIdAsync(stylistId)
            ?? throw new InvalidOperationException("Stylist not found.");

        if (stylist.ProfileId == Guid.Empty)
            throw new InvalidOperationException("This stylist has no linked Supabase Auth ID.");

        string authUserJson;
        try
        {
            authUserJson = await SendAsync(Req(HttpMethod.Get,
                $"/auth/v1/admin/users/{stylist.ProfileId}", DbKey));
        }
        catch (SupabaseException ex) when (ex.Status == HttpStatusCode.NotFound)
        {
            throw new InvalidOperationException(
                "The stylist profile is not linked to an existing Supabase Auth user. " +
                "Run Database/check_stylist_auth_link.sql to check the account before resetting its password.", ex);
        }

        var authEmail = JsonNode.Parse(authUserJson)?["email"]?.GetValue<string>();
        var profileEmail = stylist.Profile?.Email;
        if (string.IsNullOrWhiteSpace(authEmail))
            throw new InvalidOperationException(
                "Supabase Auth did not return an email for this stylist account. The password was not changed.");

        if (!string.IsNullOrWhiteSpace(profileEmail) &&
            !string.Equals(authEmail.Trim(), profileEmail.Trim(), StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "The stylist's profile email does not match their Supabase Auth email. " +
                "Check the account link before changing a password.");
        }

        await AdminUpdateUserAsync(stylist.ProfileId, new { password = newPassword });
    }

    /// <summary>Replaces the stylist's service assignments (delete-all + insert).</summary>
    private async Task SetStylistServicesAsync(long stylistId, IEnumerable<long> serviceIds)
    {
        await DeleteAsync("stylist_services", $"stylist_id=eq.{stylistId}");
        await InsertManyAsync("stylist_services",
            serviceIds.Distinct().Select(sid => (object)new { stylist_id = stylistId, service_id = sid }));
    }

    /// <summary>Marks a stylist inactive (soft delete).</summary>
    public async Task DeactivateStylistAsync(long id)
    {
        await PatchAsync("stylists", $"stylist_id=eq.{id}", new { active = false });
        Invalidate();
    }

    /// <summary>
    /// Hard-deletes a stylist, but only if they have no booking history. Cleans
    /// up schedules, services, the stylist row, auth user, and profile.
    /// </summary>
    public async Task DeleteStylistAsync(long id)
    {
        var stylist = await GetStylistByIdAsync(id);
        if (stylist == null) return;

        var anyBooking = await SelectOneAsync<Booking>("bookings", $"select=booking_id&stylist_id=eq.{id}");
        if (anyBooking != null)
            throw new InvalidOperationException(
                "This stylist has booking history, so they can't be deleted. Deactivate them instead.");

        await DeleteAsync("stylist_schedules", $"stylist_id=eq.{id}");
        try { await DeleteAsync("stylist_services", $"stylist_id=eq.{id}"); }
        catch (SupabaseException ex) when (IsMissingTable(ex)) { }
        await DeleteAsync("stylists", $"stylist_id=eq.{id}");

        // Auth/profile cleanup is best-effort: if either fails, the stylist row is already gone.
        try { await AdminDeleteUserAsync(stylist.ProfileId); } catch (SupabaseException) { }
        try { await DeleteAsync("profiles", $"id=eq.{stylist.ProfileId}"); } catch (SupabaseException) { }
        Invalidate();
    }

    // =====================================================================
    //  SCHEDULES
    // =====================================================================

    /// <summary>Default weekly schedule: Monday–Saturday on, Sunday off.</summary>
    private static Dictionary<string, DaySchedule> DefaultWeek() =>
        Days.ToDictionary(d => d, d => new DaySchedule
        {
            Enabled = d != "Sunday",
            StartTime = "09:00",
            EndTime = d == "Saturday" ? "15:00" : "17:00"
        });

    /// <summary>Collapses many date rows into a single week-pattern (min start, max end).</summary>
    private static Dictionary<string, DaySchedule> WeekFromRows(IEnumerable<StylistSchedule> rows)
    {
        var week = Days.ToDictionary(d => d, _ => new DaySchedule());
        foreach (var g in rows.GroupBy(r => r.WorkDate.DayOfWeek.ToString()))
        {
            if (!week.ContainsKey(g.Key)) continue;
            week[g.Key] = new DaySchedule
            {
                Enabled = true,
                StartTime = g.Min(r => r.StartTime).ToString(@"hh\:mm", CultureInfo.InvariantCulture),
                EndTime = g.Max(r => r.EndTime).ToString(@"hh\:mm", CultureInfo.InvariantCulture)
            };
        }
        return week;
    }

    // Loads the next few weeks of schedule rows for one stylist (or all if empty).
    private async Task<List<StylistSchedule>> ScheduleRowsAsync(string stylistFilter)
    {
        var today = DateTime.Today;
        return await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&{stylistFilter}&work_date=gte.{DateStr(today)}&work_date=lt.{DateStr(today.AddDays(ScheduleReadDays))}&order=work_date");
    }

    /// <summary>
    /// Builds the month calendar view model: shifts, blocked dates, and active
    /// booking counts grouped per day (optionally filtered to one stylist).
    /// </summary>
    public async Task<ScheduleCalendarViewModel> GetScheduleCalendarAsync(
        DateTime selectedMonth, long? selectedStylistId = null)
    {
        var first = new DateTime(selectedMonth.Year, selectedMonth.Month, 1);
        var after = first.AddMonths(1);
        var stylists = (await StylistsAsync()).Where(s => s.Active).ToList();
        // Reject unknown stylist IDs by falling back to "all stylists".
        if (selectedStylistId.HasValue && !stylists.Any(s => s.StylistId == selectedStylistId.Value))
            selectedStylistId = null;
        var stylistFilter = selectedStylistId.HasValue ? $"&stylist_id=eq.{selectedStylistId.Value}" : "";

        var rows = await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&work_date=gte.{DateStr(first)}&work_date=lt.{DateStr(after)}" +
            stylistFilter + "&order=work_date,start_time");
        var blocked = await SelectAsync<BlockedDate>("blocked_dates",
            $"select=id,stylist_id,blocked_date,reason&blocked_date=gte.{DateStr(first)}" +
            $"&blocked_date=lt.{DateStr(after)}" + stylistFilter + "&order=blocked_date");
        var bookings = await SelectAsync<Booking>("bookings",
            $"select=booking_id,stylist_id,appointment_date&appointment_date=gte.{DateStr(first)}" +
            $"&appointment_date=lt.{DateStr(after)}&status=in.(pending,confirmed,booked,incomplete)" + stylistFilter);

        var shiftsByDay = rows.GroupBy(x => x.WorkDate.Date).ToDictionary(x => x.Key, x => x.ToList());
        var blockedByDay = blocked.GroupBy(x => x.Date.Date).ToDictionary(x => x.Key, x => x.ToList());
        var bookingCounts = bookings.GroupBy(x => (x.StylistId, x.AppointmentDate.Date))
            .ToDictionary(x => x.Key, x => x.Count());
        var nameMap = stylists.ToDictionary(x => x.StylistId,
            x => x.Profile?.FullName ?? $"Stylist {x.StylistId}");
        var result = new ScheduleCalendarViewModel
        {
            Month = first,
            Stylists = stylists,
            SelectedStylistId = selectedStylistId
        };
        for (var date = first; date < after; date = date.AddDays(1))
        {
            var day = new ScheduleCalendarDay { Date = date };
            if (blockedByDay.TryGetValue(date, out var leaveDays))
            {
                foreach (var leave in leaveDays)
                    day.BlockedDates.Add(new ScheduleCalendarBlockedDate
                    {
                        StylistId = leave.StylistId,
                        StylistName = nameMap.GetValueOrDefault(leave.StylistId, $"Stylist {leave.StylistId}"),
                        Reason = string.IsNullOrWhiteSpace(leave.Reason) ? "Unavailable" : leave.Reason.Trim()
                    });
            }
            if (shiftsByDay.TryGetValue(date, out var shifts))
            {
                foreach (var shift in shifts)
                    day.Shifts.Add(new ScheduleCalendarShift
                    {
                        StylistId = shift.StylistId,
                        StylistName = nameMap.GetValueOrDefault(shift.StylistId, $"Stylist {shift.StylistId}"),
                        Hours = shift.StartTime.ToString(@"hh\:mm") + "–" + shift.EndTime.ToString(@"hh\:mm"),
                        IsAvailable = shift.IsAvailable,
                        BookingCount = bookingCounts.GetValueOrDefault((shift.StylistId, date), 0)
                    });
            }
            day.ActiveBookings = bookingCounts.Where(entry => entry.Key.Item2 == date)
                .Sum(entry => entry.Value);
            result.Days.Add(day);
        }
        return result;
    }

    /// <summary>Weekly schedule summary for every active stylist.</summary>
    public async Task<List<StylistScheduleViewModel>> GetWeeklySchedulesAsync()
    {
        var stylists = (await StylistsAsync()).Where(s => s.Active).ToList();
        var rows = await ScheduleRowsAsync("stylist_id=gt.0");

        return stylists.Select(s => new StylistScheduleViewModel
        {
            StylistId = s.StylistId,
            StylistName = s.Profile?.FullName ?? "",
            WeekSchedule = WeekFromRows(rows.Where(r => r.StylistId == s.StylistId))
        }).ToList();
    }

    /// <summary>Upcoming blocked dates (next 6 months) for one stylist.</summary>
    public async Task<List<ScheduleBlockedDateViewModel>> GetBlockedDatesForStylistAsync(long stylistId)
    {
        var today = DateTime.Today;
        var rows = await SelectAsync<BlockedDate>("blocked_dates",
            $"select=id,stylist_id,blocked_date,reason&stylist_id=eq.{stylistId}" +
            $"&blocked_date=gte.{DateStr(today)}&blocked_date=lt.{DateStr(today.AddMonths(6))}" +
            "&order=blocked_date");
        return rows.OrderBy(x => x.Date).Select(x => new ScheduleBlockedDateViewModel
        {
            Date = x.Date.Date,
            Reason = string.IsNullOrWhiteSpace(x.Reason) ? "Unavailable" : x.Reason.Trim()
        }).ToList();
    }

    /// <summary>Combines weekly pattern + upcoming blocked dates for one stylist.</summary>
    public async Task<ScheduleViewModel?> GetStylistScheduleAsync(long stylistId)
    {
        var s = await GetStylistByIdAsync(stylistId);
        if (s == null) return null;

        var rows = await ScheduleRowsAsync($"stylist_id=eq.{stylistId}");
        return new ScheduleViewModel
        {
            StylistId = stylistId,
            StylistName = s.Profile?.FullName,
            WeekSchedule = WeekFromRows(rows),
            BlockedDates = await GetBlockedDatesForStylistAsync(stylistId)
        };
    }

    // Normalises any date to the Monday of its ISO week.
    private static DateTime WeekMonday(DateTime date) =>
        date.Date.AddDays(-(((int)date.DayOfWeek + 6) % 7));

    /// <summary>Only the current week + the next 7 weeks can be edited.</summary>
    private static void ValidateEditableWeek(DateTime monday)
    {
        var currentMonday = WeekMonday(DateTime.Today);
        if (monday != WeekMonday(monday) ||
            monday < currentMonday || monday > currentMonday.AddDays(49))
            throw new InvalidOperationException(
                "Choose the current week or one of the next seven weeks.");
    }

    /// <summary>Builds the editable week view (7 rows) for a stylist.</summary>
    public async Task<ScheduleViewModel?> GetStylistWeekEditAsync(
        long stylistId, DateTime? selectedWeek = null)
    {
        var stylist = await GetStylistByIdAsync(stylistId);
        if (stylist == null) return null;

        var monday = WeekMonday(selectedWeek ?? DateTime.Today);
        ValidateEditableWeek(monday);
        var sundayEnd = monday.AddDays(7);
        var dateFilter = $"&work_date=gte.{DateStr(monday)}&work_date=lt.{DateStr(sundayEnd)}";

        var rows = await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&stylist_id=eq.{stylistId}{dateFilter}&order=work_date,start_time");
        var blocked = await SelectAsync<BlockedDate>("blocked_dates",
            $"select=id,stylist_id,blocked_date,reason&stylist_id=eq.{stylistId}" +
            $"&blocked_date=gte.{DateStr(monday)}&blocked_date=lt.{DateStr(sundayEnd)}");
        var booked = await SelectAsync<Booking>("bookings",
            $"select=booking_id,appointment_date&stylist_id=eq.{stylistId}" +
            $"&appointment_date=gte.{DateStr(monday)}&appointment_date=lt.{DateStr(sundayEnd)}" +
            "&status=in.(pending,confirmed,booked,incomplete)");

        var blockedDates = blocked.GroupBy(x => x.Date.Date)
            .ToDictionary(g => g.Key, g => g.First());
        var bookedDates = booked.Select(x => x.AppointmentDate.Date).ToHashSet();
        var result = new ScheduleViewModel
        {
            StylistId = stylistId,
            StylistName = stylist.Profile?.FullName,
            WeekStart = monday
        };
        for (var date = monday; date < sundayEnd; date = date.AddDays(1))
        {
            var dayRows = rows.Where(r => r.WorkDate.Date == date).ToList();
            blockedDates.TryGetValue(date, out var blockedDate);
            var firstShift = dayRows.FirstOrDefault();
            result.DateRows.Add(new ScheduleDateRowViewModel
            {
                Date = date,
                IsBlocked = blockedDate != null,
                BlockedReason = blockedDate == null ? null :
                    (string.IsNullOrWhiteSpace(blockedDate.Reason) ? "No reason provided" : blockedDate.Reason.Trim()),
                HasBooking = bookedDates.Contains(date),
                IsPast = date < DateTime.Today,
                Enabled = blockedDate == null && dayRows.Any(x => x.IsAvailable),
                StartTime = dayRows.Count > 0
                    ? dayRows.Min(x => x.StartTime).ToString(@"hh\:mm", CultureInfo.InvariantCulture)
                    : "09:00",
                EndTime = dayRows.Count > 0
                    ? dayRows.Max(x => x.EndTime).ToString(@"hh\:mm", CultureInfo.InvariantCulture)
                    : (date.DayOfWeek == DayOfWeek.Saturday ? "15:00" : "17:00")
            });
        }
        return result;
    }

    /// <summary>Active bookings for one stylist within the selected ISO week.</summary>
    public async Task<List<Booking>> GetWeeklyBookingsByStylistAsync(
        long stylistId, DateTime? selectedWeek = null)
    {
        var monday = WeekMonday(selectedWeek ?? DateTime.Today);
        var list = await SelectAsync<Booking>("bookings",
            $"select=*&stylist_id=eq.{stylistId}&status=in.(pending,confirmed,booked,incomplete)" +
            $"&appointment_date=gte.{DateStr(monday)}&appointment_date=lt.{DateStr(monday.AddDays(7))}" +
            "&order=appointment_date,start_time");
        await HydrateAsync(list);
        return list;
    }

    /// <summary>
    /// Saves a specific 7-day week for a stylist. Rejects edits to days that
    /// already have an active booking or are blocked by leave.
    /// </summary>
    public async Task UpdateSpecificWeekAsync(long stylistId, ScheduleViewModel model)
    {
        var monday = model.WeekStart.Date;
        ValidateEditableWeek(monday);
        // Model must contain exactly 7 distinct, contiguous days starting Monday.
        if (model.StylistId != stylistId || model.DateRows == null || model.DateRows.Count != 7 ||
            model.DateRows.Select(x => x.Date.Date).Distinct().Count() != 7 ||
            model.DateRows.Any(x => x.Date.Date < monday || x.Date.Date >= monday.AddDays(7)))
            throw new InvalidOperationException("Invalid week selection. Reload the page and try again.");

        var last = monday.AddDays(7);
        var rows = await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&stylist_id=eq.{stylistId}&work_date=gte.{DateStr(monday)}" +
            $"&work_date=lt.{DateStr(last)}&order=work_date,start_time");
        var blocked = await SelectAsync<BlockedDate>("blocked_dates",
            $"select=id,stylist_id,blocked_date&stylist_id=eq.{stylistId}" +
            $"&blocked_date=gte.{DateStr(monday)}&blocked_date=lt.{DateStr(last)}");
        var bookings = await SelectAsync<Booking>("bookings",
            $"select=booking_id,appointment_date&stylist_id=eq.{stylistId}" +
            $"&appointment_date=gte.{DateStr(monday)}&appointment_date=lt.{DateStr(last)}" +
            "&status=in.(pending,confirmed,booked,incomplete)");

        var blockedDates = blocked.Select(x => x.Date.Date).ToHashSet();
        var bookedDates = bookings.Select(x => x.AppointmentDate.Date).ToHashSet();

        var changes = new List<(DateTime Date, bool Enabled, TimeSpan Start, TimeSpan End)>();
        foreach (var item in model.DateRows.OrderBy(x => x.Date))
        {
            var date = item.Date.Date;
            // Skip days that are past, blocked, or already booked.
            if (date < DateTime.Today || bookedDates.Contains(date) || blockedDates.Contains(date))
                continue;
            TimeSpan start = default, end = default;
            if (item.Enabled &&
                (!TimeSpan.TryParseExact(item.StartTime, @"hh\:mm", CultureInfo.InvariantCulture, out start) ||
                 !TimeSpan.TryParseExact(item.EndTime, @"hh\:mm", CultureInfo.InvariantCulture, out end) ||
                 end <= start))
                throw new InvalidOperationException($"Enter valid working hours for {date:dd MMM yyyy}.");
            changes.Add((date, item.Enabled, start, end));
        }

        // Mark blocked days' existing shifts as unavailable (unless booked).
        foreach (var date in blockedDates)
        {
            if (bookedDates.Contains(date)) continue;
            var ids = rows.Where(x => x.WorkDate.Date == date && x.IsAvailable)
                .Select(x => x.ScheduleId).ToList();
            if (ids.Count > 0)
                await PatchAsync("stylist_schedules", $"schedule_id=in.{InList(ids)}",
                    new { is_available = false });
        }

        foreach (var change in changes)
        {
            var dayRows = rows.Where(r => r.WorkDate.Date == change.Date).ToList();
            if (!change.Enabled)
            {
                // Disable day: mark all available shifts unavailable.
                var availableIds = dayRows.Where(x => x.IsAvailable).Select(x => x.ScheduleId).ToList();
                if (availableIds.Count > 0)
                    await PatchAsync("stylist_schedules", $"schedule_id=in.{InList(availableIds)}",
                        new { is_available = false });
                continue;
            }

            if (dayRows.Count == 0)
            {
                // New shift row for this day.
                await InsertAsync("stylist_schedules", new
                {
                    stylist_id = stylistId,
                    work_date = DateStr(change.Date),
                    start_time = TimeStr(change.Start),
                    end_time = TimeStr(change.End),
                    is_available = true
                });
            }
            else
            {
                // Keep one row (patch it), delete any duplicates.
                var first = dayRows[0];
                if (!first.IsAvailable || first.StartTime != change.Start || first.EndTime != change.End)
                    await PatchAsync("stylist_schedules", $"schedule_id=eq.{first.ScheduleId}",
                        new { start_time = TimeStr(change.Start), end_time = TimeStr(change.End), is_available = true });
                var duplicateIds = dayRows.Skip(1).Select(x => x.ScheduleId).ToList();
                if (duplicateIds.Count > 0)
                    await DeleteAsync("stylist_schedules", $"schedule_id=in.{InList(duplicateIds)}");
            }
        }
    }

    /// <summary>
    /// Applies a weekly pattern across the next 8 weeks. Refuses changes to
    /// days that already have active bookings. Respects leave-blocked days.
    /// </summary>
    private async Task SaveWeekAsync(long stylistId, Dictionary<string, DaySchedule> week)
    {
        var today = DateTime.Today;
        var end = today.AddDays(ScheduleDays);

        var existing = await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&stylist_id=eq.{stylistId}&work_date=gte.{DateStr(today)}&work_date=lt.{DateStr(end)}&order=work_date");

        var activeBookings = await SelectAsync<Booking>("bookings",
            $"select=booking_id,appointment_date&stylist_id=eq.{stylistId}" +
            $"&appointment_date=gte.{DateStr(today)}&appointment_date=lt.{DateStr(end)}" +
            "&status=in.(pending,confirmed,booked,incomplete)");
        var blockedRows = await SelectAsync<BlockedDate>("blocked_dates",
            $"select=id,stylist_id,blocked_date&stylist_id=eq.{stylistId}" +
            $"&blocked_date=gte.{DateStr(today)}&blocked_date=lt.{DateStr(end)}");
        var blockedDates = blockedRows.Select(x => x.Date.Date).ToHashSet();

        // Refuse to shrink hours on days with active bookings.
        var bookedDates = activeBookings.Select(b => b.AppointmentDate.Date).ToHashSet();
        foreach (var bookedDate in bookedDates)
        {
            week.TryGetValue(bookedDate.DayOfWeek.ToString(), out var bookedDay);
            var scheduledRows = existing.Where(r => r.WorkDate.Date == bookedDate).ToList();
            TimeSpan desiredStart = default, desiredEnd = default;
            var enabled = bookedDay != null && bookedDay.Enabled &&
                          TimeSpan.TryParse(bookedDay.StartTime, CultureInfo.InvariantCulture, out desiredStart) &&
                          TimeSpan.TryParse(bookedDay.EndTime, CultureInfo.InvariantCulture, out desiredEnd) &&
                          desiredEnd > desiredStart;
            if (!enabled || scheduledRows.Count == 0 ||
                scheduledRows.Min(r => r.StartTime) != desiredStart ||
                scheduledRows.Max(r => r.EndTime) != desiredEnd)
                throw new InvalidOperationException(
                    $"Schedule cannot be changed on {bookedDate:dd MMM yyyy}: this stylist has an active booking. Complete, cancel, or reschedule it first.");
        }

        var inserts = new List<object>();
        var deleteIds = new List<long>();

        for (var date = today; date < end; date = date.AddDays(1))
        {
            week.TryGetValue(date.DayOfWeek.ToString(), out var day);
            var rows = existing.Where(r => r.WorkDate.Date == date).ToList();

            // Leave-blocked days: mark shifts unavailable, do not create new shifts.
            if (blockedDates.Contains(date))
            {
                var availableIds = rows.Where(r => r.IsAvailable)
                    .Select(r => r.ScheduleId).ToList();
                if (availableIds.Count > 0)
                    await PatchAsync("stylist_schedules",
                        $"schedule_id=in.{InList(availableIds)}",
                        new { is_available = false });
                continue;
            }

            TimeSpan start = default, finish = default;
            var enabled = day != null && day.Enabled &&
                          TimeSpan.TryParse(day.StartTime, CultureInfo.InvariantCulture, out start) &&
                          TimeSpan.TryParse(day.EndTime, CultureInfo.InvariantCulture, out finish) &&
                          finish > start;

            if (enabled)
            {
                if (rows.Count == 0)
                {
                    inserts.Add(new
                    {
                        stylist_id = stylistId,
                        work_date = DateStr(date),
                        start_time = TimeStr(start),
                        end_time = TimeStr(finish),
                        is_available = true
                    });
                }
                else
                {
                    var currentRow = rows[0];
                    if (currentRow.StartTime != start || currentRow.EndTime != finish || !currentRow.IsAvailable)
                    {
                        await PatchAsync("stylist_schedules",
                            $"schedule_id=eq.{currentRow.ScheduleId}",
                            new { start_time = TimeStr(start), end_time = TimeStr(finish), is_available = true });
                    }
                }
            }
            else
            {
                // Day is off: remove available shifts (batched at the end).
                deleteIds.AddRange(rows.Where(r => r.IsAvailable).Select(r => r.ScheduleId));
            }
        }

        await InsertManyAsync("stylist_schedules", inserts);
        if (deleteIds.Count > 0)
            await DeleteAsync("stylist_schedules", $"schedule_id=in.{InList(deleteIds)}");
    }

    public Task SaveScheduleAsync(ScheduleViewModel model) => SaveWeekAsync(model.StylistId, model.WeekSchedule);

    public Task UpdateScheduleAsync(long stylistId, ScheduleViewModel model) => SaveWeekAsync(stylistId, model.WeekSchedule);

    /// <summary>Deletes upcoming available shifts, but only if no future active bookings exist.</summary>
    public async Task DeleteScheduleAsync(long stylistId)
    {
        var booking = await SelectOneAsync<Booking>("bookings",
            $"select=booking_id&stylist_id=eq.{stylistId}&appointment_date=gte.{DateStr(DateTime.Today)}" +
            "&status=in.(pending,confirmed,booked,incomplete)");
        if (booking != null)
            throw new InvalidOperationException(
                "This stylist has upcoming bookings. Complete, cancel, or reschedule them before deleting their schedule.");
        await DeleteAsync("stylist_schedules",
            $"stylist_id=eq.{stylistId}&work_date=gte.{DateStr(DateTime.Today)}&is_available=eq.true");
    }

    // =====================================================================
    //  SERVICES
    // =====================================================================
    public async Task<List<Service>> GetAllServicesAsync() => (await ServicesAsync()).ToList();

    public async Task<Service?> GetServiceByIdAsync(long id) =>
        (await ServicesAsync()).FirstOrDefault(s => s.ServiceId == id);

    public async Task CreateServiceAsync(Service service)
    {
        await InsertAsync("services", new
        {
            name = service.Name,
            description = service.Description,
            price = service.Price,
            duration_minutes = service.DurationMinutes,
            image_url = service.ImageUrl,
            is_flagship = service.IsFlagship,
            active = service.Active
        });
        Invalidate();
    }

    public async Task UpdateServiceAsync(Service service)
    {
        await PatchAsync("services", $"service_id=eq.{service.ServiceId}", new
        {
            name = service.Name,
            description = service.Description,
            price = service.Price,
            duration_minutes = service.DurationMinutes,
            image_url = service.ImageUrl,
            is_flagship = service.IsFlagship,
            active = service.Active
        });
        Invalidate();
    }

    /// <summary>
    /// Deletes a service, but only if it has no booking history. Cleans up
    /// promotions and stylist_services links first.
    /// </summary>
    public async Task DeleteServiceAsync(long id)
    {
        var anyBooking = await SelectOneAsync<Booking>("bookings", $"select=booking_id&service_id=eq.{id}");
        if (anyBooking != null)
            throw new InvalidOperationException(
                "This service has booking history, so it can't be deleted. Mark it inactive instead.");

        await DeleteAsync("promotions", $"service_id=eq.{id}");
        try { await DeleteAsync("stylist_services", $"service_id=eq.{id}"); }
        catch (SupabaseException ex) when (IsMissingTable(ex)) { }
        await DeleteAsync("services", $"service_id=eq.{id}");
        Invalidate();
    }

    // =====================================================================
    //  PROMOTIONS
    // =====================================================================
    public async Task<List<Promotion>> GetAllPromotionsAsync()
    {
        var list = await SelectAsync<Promotion>("promotions", "select=*&order=start_date.desc");
        await HydrateAsync(list);
        return list;
    }

    public async Task<List<Promotion>> GetActivePromotionsAsync()
    {
        var list = await SelectAsync<Promotion>("promotions", "select=*&active=eq.true&order=start_date.desc");
        await HydrateAsync(list);
        return list;
    }

    public async Task<Promotion?> GetPromotionByIdAsync(long id)
    {
        var p = await SelectOneAsync<Promotion>("promotions", $"select=*&promotion_id=eq.{id}");
        if (p != null) await HydrateAsync(new List<Promotion> { p });
        return p;
    }

    public Task CreatePromotionAsync(Promotion p) => InsertAsync("promotions", new
    {
        service_id = p.ServiceId,
        title = p.Title,
        description = p.Description,
        discount_type = p.DiscountType,
        discount_value = p.DiscountValue,
        start_date = DateStr(p.StartDate),
        end_date = DateStr(p.EndDate),
        active = p.Active,
        image_url = p.ImageUrl
    });

    public Task UpdatePromotionAsync(Promotion p) => PatchAsync("promotions", $"promotion_id=eq.{p.PromotionId}", new
    {
        service_id = p.ServiceId,
        title = p.Title,
        description = p.Description,
        discount_type = p.DiscountType,
        discount_value = p.DiscountValue,
        start_date = DateStr(p.StartDate),
        end_date = DateStr(p.EndDate),
        active = p.Active,
        image_url = p.ImageUrl
    });

    public Task DeletePromotionAsync(long id) => DeleteAsync("promotions", $"promotion_id=eq.{id}");

    // =====================================================================
    //  REVIEWS
    // =====================================================================

    /// <summary>
    /// Returns reviews filtered by rating, stylist, date, and free-text search.
    /// Returns an empty list when the reviews table is missing.
    /// </summary>
    public async Task<List<Review>> GetFilteredReviewsAsync(string? rating, long? stylistId, DateTime? date, string? search)
    {
        var filters = new List<string> { "select=*" };
        if (int.TryParse(rating, out var r)) filters.Add($"rating=eq.{r}");
        if (stylistId.HasValue && stylistId.Value > 0) filters.Add($"stylist_id=eq.{stylistId.Value}");
        if (date.HasValue)
        {
            filters.Add($"created_at=gte.{Iso(date.Value.Date)}");
            filters.Add($"created_at=lt.{Iso(date.Value.Date.AddDays(1))}");
        }
        filters.Add("order=created_at.desc");
        filters.Add("limit=500");

        try
        {
            var list = await SelectAsync<Review>("reviews", string.Join("&", filters));
            await HydrateAsync(list);

            // Search is applied client-side over joined names.
            if (!string.IsNullOrWhiteSpace(search))
                list = list.Where(x =>
                    (x.Customer?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                    (x.Stylist?.Profile?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase)).ToList();

            return list;
        }
        catch (SupabaseException ex) when (IsMissingTable(ex))
        {
            return new List<Review>();
        }
    }

    /// <summary>Computes headline stats: average, total, follow-ups, this-week count.</summary>
    public async Task<ReviewSummary> GetReviewSummaryAsync()
    {
        try
        {
            var all = await SelectAsync<Review>("reviews",
                "select=review_id,rating,service_rating,follow_up_required,resolved,created_at");

            var today = DateTime.Today;
            var monday = today.AddDays(-(((int)today.DayOfWeek + 6) % 7));
            var thisWeekCount = all.Count(r => r.CreatedAt.Date >= monday);

            return new ReviewSummary
            {
                AverageRating = all.Count == 0 ? 0 : Math.Round(all.Average(x => x.Rating), 1),
                TotalReviews = all.Count,
                // Follow-up required for low ratings that aren't resolved yet.
                NeedsFollowUp = all.Count(x => (x.Rating <= 2 || (x.ServiceRating.HasValue && x.ServiceRating.Value <= 2)) && !x.Resolved),
                ThisWeekCount = thisWeekCount
            };
        }
        catch (SupabaseException ex) when (IsMissingTable(ex))
        {
            return new ReviewSummary();
        }
    }

    public async Task<Review?> GetReviewByIdAsync(Guid id)
    {
        var r = await SelectOneAsync<Review>("reviews", $"select=*&review_id=eq.{id}");
        if (r != null) await HydrateAsync(new List<Review> { r });
        return r;
    }

    // Returns the existing follow-up record, or an empty placeholder for new reviews.
    public async Task<ReviewFollowUpRecord> GetReviewFollowUpAsync(Guid reviewId) =>
        await SelectOneAsync<ReviewFollowUpRecord>("review_followups",
            $"select=*&review_id=eq.{reviewId}")
        ?? new ReviewFollowUpRecord { ReviewId = reviewId };

    /// <summary>Creates a follow-up row for a review if one doesn't exist yet.</summary>
    public async Task EnsureReviewFollowUpAsync(Guid reviewId)
    {
        var existing = await SelectOneAsync<ReviewFollowUpRecord>("review_followups",
            $"select=review_id&review_id=eq.{reviewId}");
        if (existing == null)
        {
            await UpsertAsync("review_followups", "review_id", new { review_id = reviewId });
        }
    }

    public Task RecordCustomerApologyAsync(Guid reviewId, string recipient, string subject,
        string message, string managerEmail) =>
        PatchAsync("review_followups", $"review_id=eq.{reviewId}", new
        {
            customer_sent_at = DateTimeOffset.UtcNow,
            customer_sent_to = recipient,
            apology_subject = subject,
            apology_message = message,
            manager_email = managerEmail
        });

    public Task RecordStylistReportAsync(Guid reviewId, string recipient,
        string message, string managerEmail) =>
        PatchAsync("review_followups", $"review_id=eq.{reviewId}", new
        {
            stylist_sent_at = DateTimeOffset.UtcNow,
            stylist_sent_to = recipient,
            stylist_report = message,
            manager_email = managerEmail
        });

    /// <summary>Sends the apology notification to the customer's Flutter app. Returns success.</summary>
    public async Task<bool> SendReviewApologyNotificationAsync(Guid reviewId,
        string subject, string message, string managerEmail)
    {
        var text = await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/send_review_apology_notification", DbKey, new
            {
                p_review_id = reviewId,
                p_subject = subject,
                p_message = message,
                p_manager_email = managerEmail
            }));
        return JsonSerializer.Deserialize<bool>(text, Json);
    }

    /// <summary>Sends the review report notification to the stylist's app. Returns success.</summary>
    public async Task<bool> SendReviewStylistReportNotificationAsync(Guid reviewId,
        string title, string message, string managerEmail)
    {
        var text = await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/send_review_stylist_report_notification", DbKey, new
            {
                p_review_id = reviewId,
                p_title = title,
                p_message = message,
                p_manager_email = managerEmail
            }));
        return JsonSerializer.Deserialize<bool>(text, Json);
    }

    /// <summary>
    /// Marks a review resolved only after both the customer apology and the
    /// stylist report notifications have been recorded/sent.
    /// </summary>
    public async Task MarkReviewResolvedAsync(Guid id)
    {
        var followUp = await GetReviewFollowUpAsync(id);
        if (!followUp.CustomerNotifiedAt.HasValue && !followUp.CustomerSentAt.HasValue)
            throw new InvalidOperationException(
                "Send the customer an apology notification before resolving this review.");
        if (!followUp.StylistNotifiedAt.HasValue)
            throw new InvalidOperationException(
                "Send the feedback report to the stylist's Flutter Notifications before resolving this review.");
        await PatchAsync("reviews", $"review_id=eq.{id}", new { resolved = true });
    }

    // =====================================================================
    //  REPORTS
    // =====================================================================

    /// <summary>
    /// Builds a full report: revenue breakdown, per-day/week bars, service
    /// demand, and per-stylist booking rows. Periods: weekly, monthly, custom.
    /// </summary>
    public async Task<ReportData> GetReportAsync(string period, DateTime? from, DateTime? to)
    {
        var today = DateTime.Today;
        DateTime start, end;
        string label;

        switch (period)
        {
            case "weekly":
                start = today.AddDays(-6);
                end = today;
                label = $"{start:dd MMM} - {end:dd MMM yyyy}";
                break;
            case "custom":
                start = (from ?? today.AddDays(-29)).Date;
                end = (to ?? today).Date;
                // Swap if the user reversed the range.
                if (end < start) (start, end) = (end, start);
                label = from.HasValue && to.HasValue ? $"{start:dd MMM yyyy} - {end:dd MMM yyyy}" : "Custom range";
                break;
            default:
                period = "monthly";
                start = new DateTime(today.Year, today.Month, 1);
                end = start.AddMonths(1).AddDays(-1);
                label = today.ToString("MMMM yyyy");
                break;
        }

        // Page through all bookings in the range to avoid PostgREST row limits.
        var bookings = new List<Booking>();
        const int pageSize = 500;
        for (var offset = 0; ; offset += pageSize)
        {
            var page = await SelectAsync<Booking>("bookings",
                $"select=booking_id,customer_id,stylist_id,service_id,payment_method_id,appointment_date,status" +
                $"&appointment_date=gte.{DateStr(start)}&appointment_date=lte.{DateStr(end)}" +
                $"&order=appointment_date.asc,booking_id.asc&limit={pageSize}&offset={offset}");
            bookings.AddRange(page);
            if (page.Count < pageSize) break;
        }
        var completed = bookings.Where(b => b.Status.Equals("completed", StringComparison.OrdinalIgnoreCase)).ToList();

        var services = await ServicesAsync();
        var payments = await PaymentsAsync();

        var cancelled = await SelectAsync<Cancellation>("cancellations",
            $"select=cancellation_id&cancelled_at=gte.{Iso(start)}&cancelled_at=lt.{Iso(end.AddDays(1))}");

        decimal cash = 0, card = 0;
        var serviceCounts = new Dictionary<string, int>();

        // First pass: totals + service demand across the whole period.
        foreach (var b in completed)
        {
            var svc = services.FirstOrDefault(s => s.ServiceId == b.ServiceId);
            var price = svc?.Price ?? 0;
            var method = payments.FirstOrDefault(p => p.PaymentMethodId == b.PaymentMethodId)?.MethodName ?? "";

            if (method.Equals("Card", StringComparison.OrdinalIgnoreCase)) card += price;
            else cash += price;

            var svcName = svc?.Name ?? "Unknown";
            serviceCounts[svcName] = serviceCounts.GetValueOrDefault(svcName) + 1;
        }

        var bars = new List<RevenueBar>();
        var totalDays = (end - start).Days + 1;
        // Long periods (> 2 weeks) are bucketed by week; short periods by day.
        var groupByWeek = totalDays > 14;

        if (groupByWeek)
        {
            var weekStart = start;
            int weekNum = 1;
            while (weekStart <= end)
            {
                var weekEnd = weekStart.AddDays(6);
                if (weekEnd > end) weekEnd = end;

                decimal wCash = 0, wCard = 0;
                foreach (var b in completed.Where(x =>
                    x.AppointmentDate.Date >= weekStart && x.AppointmentDate.Date <= weekEnd))
                {
                    var price = services.FirstOrDefault(s => s.ServiceId == b.ServiceId)?.Price ?? 0;
                    var method = payments.FirstOrDefault(p => p.PaymentMethodId == b.PaymentMethodId)?.MethodName ?? "";
                    if (method.Equals("Card", StringComparison.OrdinalIgnoreCase)) wCard += price;
                    else wCash += price;
                }

                bars.Add(new RevenueBar { Label = $"Week {weekNum}", Cash = wCash, Card = wCard });
                weekStart = weekEnd.AddDays(1);
                weekNum++;
            }
        }
        else
        {
            for (var date = start; date <= end; date = date.AddDays(1))
            {
                decimal dCash = 0, dCard = 0;
                foreach (var b in completed.Where(x => x.AppointmentDate.Date == date))
                {
                    var price = services.FirstOrDefault(s => s.ServiceId == b.ServiceId)?.Price ?? 0;
                    var method = payments.FirstOrDefault(p => p.PaymentMethodId == b.PaymentMethodId)?.MethodName ?? "";
                    if (method.Equals("Card", StringComparison.OrdinalIgnoreCase)) dCard += price;
                    else dCash += price;
                }

                bars.Add(new RevenueBar
                {
                    Label = date.ToString("ddd dd"),
                    Cash = dCash,
                    Card = dCard
                });
            }
        }

        // Top 4 services by booking count, with % of total.
        var total = completed.Count == 0 ? 1 : completed.Count;
        var demand = serviceCounts
            .OrderByDescending(kv => kv.Value)
            .Take(4)
            .Select(kv => new ServiceDemand
            {
                Name = kv.Key,
                Count = kv.Value,
                Percent = (int)Math.Round((double)kv.Value / total * 100)
            })
            .ToList();

        // Hydrate customer/stylist/service names for the detailed table rows.
        var profiles = await ProfilesAsync(bookings.Select(b => b.CustomerId));
        var stylists = await StylistsAsync();
        var reportRows = bookings.Select(b =>
        {
            var service = services.FirstOrDefault(x => x.ServiceId == b.ServiceId);
            var payment = payments.FirstOrDefault(x => x.PaymentMethodId == b.PaymentMethodId);
            var stylist = stylists.FirstOrDefault(x => x.StylistId == b.StylistId);
            var done = b.Status.Equals("completed", StringComparison.OrdinalIgnoreCase);
            return new StylistBookingReportRow
            {
                BookingId = b.BookingId,
                CustomerName = profiles.GetValueOrDefault(b.CustomerId)?.FullName ?? "Unknown customer",
                StylistName = stylist?.Profile?.FullName ?? "Unknown stylist",
                ServiceName = service?.Name ?? "Unknown service",
                AppointmentDate = b.AppointmentDate,
                Price = service?.Price ?? 0m,
                PaymentMethod = payment?.MethodName ?? "Not specified",
                Status = ToAppStatus(b.Status),
                AmountPaid = done ? service?.Price ?? 0m : null
            };
        }).ToList();

        return new ReportData
        {
            Period = period,
            PeriodLabel = label,
            CompletedBookings = completed.Count,
            Cancelled = cancelled.Count,
            CashRevenue = cash,
            CardRevenue = card,
            RevenueBars = bars,
            ServiceDemand = demand,
            StylistBookings = reportRows
        };
    }

    // PDF generation is synchronous but exposed as Task for controller symmetry.
    public Task<byte[]> GenerateReportPdfAsync(ReportData report) =>
        Task.FromResult(ReportPdfBuilder.Build(report));

    // =====================================================================
    //  GALLERY
    // =====================================================================
    public Task<List<GalleryImage>> GetAllGalleryImagesAsync() =>
        SelectAsync<GalleryImage>("gallery_images", "select=*&order=created_at.desc");

    /// <summary>Returns the editable About Us text, falling back to a default if unset/missing.</summary>
    public async Task<string> GetAboutUsContentAsync()
    {
        try
        {
            var row = await SelectOneAsync<SettingRow>("site_settings", "select=*&setting_key=eq.about_us");
            return string.IsNullOrWhiteSpace(row?.SettingValue) ? DefaultAboutUs : row!.SettingValue!;
        }
        catch (SupabaseException ex) when (IsMissingTable(ex))
        {
            return DefaultAboutUs;
        }
    }

    public Task UpdateAboutUsAsync(string aboutUs) =>
        UpsertAsync("site_settings", "setting_key", new { setting_key = "about_us", setting_value = aboutUs ?? "" });

    private class SettingRow
    {
        public string SettingKey { get; set; } = "";
        public string? SettingValue { get; set; }
    }

    /// <summary>Uploads an image to storage and inserts the corresponding gallery_images row.</summary>
    public async Task UploadGalleryImageAsync(IFormFile file, string title, string? description)
    {
        var uploader = await CurrentProfileIdAsync()
            ?? throw new InvalidOperationException("Couldn't work out who is signed in. Please sign in again.");

        var ext = System.IO.Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp" or ".gif"))
            throw new InvalidOperationException("Please upload a JPG, PNG, WEBP or GIF image.");

        if (file.Length > 2 * 1024 * 1024)
            throw new InvalidOperationException("Gallery images must be no larger than 2 MB.");
        var objectName = $"salon/{Guid.NewGuid():N}{ext}";

        using var ms = new MemoryStream();
        await file.CopyToAsync(ms);

        var req = Req(HttpMethod.Post, $"/storage/v1/object/{GalleryBucket}/{objectName}", DbKey);
        var content = new ByteArrayContent(ms.ToArray());
        content.Headers.ContentType = new MediaTypeHeaderValue(
            string.IsNullOrWhiteSpace(file.ContentType) ? "application/octet-stream" : file.ContentType);
        req.Content = content;
        await SendAsync(req);

        var publicUrl = $"{BaseUrl}/storage/v1/object/public/{GalleryBucket}/{objectName}";
        await InsertAsync("gallery_images", new
        {
            uploaded_by = uploader,
            title = string.IsNullOrWhiteSpace(title) ? file.FileName : title,
            description,
            image_url = publicUrl
        });
    }

    public Task UpdateGalleryImageAsync(long id, string title, string? description) =>
        PatchAsync("gallery_images", $"image_id=eq.{id}", new { title, description });

    /// <summary>Deletes the gallery row and best-effort removes the underlying object from storage.</summary>
    public async Task DeleteGalleryImageAsync(long id)
    {
        var image = await SelectOneAsync<GalleryImage>("gallery_images", $"select=*&image_id=eq.{id}");
        await DeleteAsync("gallery_images", $"image_id=eq.{id}");

        // Try both the current bucket name and a legacy "gallery" bucket.
        var url = image?.ImageUrl ?? "";
        foreach (var bucket in new[] { GalleryBucket, "gallery" }.Distinct())
        {
            var marker = $"/storage/v1/object/public/{bucket}/";
            var at = url.IndexOf(marker, StringComparison.Ordinal);
            if (at < 0) continue;
            var objectName = url[(at + marker.Length)..];
            try { await SendAsync(Req(HttpMethod.Delete, $"/storage/v1/object/{bucket}/{objectName}", DbKey)); }
            catch (SupabaseException) { }
            break;
        }
    }

    // =====================================================================
    //  SERVICE / PROMOTION IMAGES
    // =====================================================================
    /// <summary>
    /// Uploads a validated JPG/PNG to the catalog bucket and returns its public URL.
    /// Validates magic bytes, not just the file extension.
    /// </summary>
    public async Task<string> UploadCatalogImageAsync(IFormFile file, string folder)
    {
        if (file.Length == 0 || file.Length > 2 * 1024 * 1024)
            throw new InvalidOperationException("Choose a JPG or PNG image smaller than 2 MB.");
        if (folder is not ("services" or "promotions"))
            throw new ArgumentException("Invalid image destination.", nameof(folder));

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png"))
            throw new InvalidOperationException("Only JPG and PNG images are supported.");
        await using var stream = new MemoryStream();
        await file.CopyToAsync(stream);
        var bytes = stream.ToArray();
        // Magic-byte checks: JPEG starts FF D8 FF; PNG starts 89 50 4E 47 0D 0A 1A 0A.
        var isJpeg = bytes.Length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
        var isPng = bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(
            new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 });
        if (!(ext is ".jpg" or ".jpeg" ? isJpeg : isPng))
            throw new InvalidOperationException("The uploaded file is not a valid JPG or PNG image.");

        var objectName = $"{folder}/{Guid.NewGuid():N}{(isJpeg ? ".jpg" : ".png")}";
        using var req = Req(HttpMethod.Post,
            $"/storage/v1/object/{CatalogImagesBucket}/{objectName}", DbKey);
        req.Content = new ByteArrayContent(bytes);
        req.Content.Headers.ContentType = new MediaTypeHeaderValue(isJpeg ? "image/jpeg" : "image/png");
        try { await SendAsync(req); }
        catch (SupabaseException ex) when (ex.Status == HttpStatusCode.NotFound ||
                                            ex.Message.Contains("bucket", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "The catalog-images Storage bucket is missing. Run Database/catalog_and_booking_rules.sql in Supabase first.", ex);
        }
        return $"{BaseUrl}/storage/v1/object/public/{CatalogImagesBucket}/{objectName}";
    }

    /// <summary>Best-effort deletion of a previously-uploaded catalog image.</summary>
    public async Task DeleteCatalogImageAsync(string? publicUrl)
    {
        if (string.IsNullOrWhiteSpace(publicUrl)) return;
        var prefix = $"{BaseUrl}/storage/v1/object/public/{CatalogImagesBucket}/";
        if (!publicUrl.StartsWith(prefix, StringComparison.Ordinal)) return;
        var objectName = publicUrl[prefix.Length..];
        // Only delete objects created by the catalog flow.
        if (!objectName.StartsWith("services/", StringComparison.Ordinal) &&
            !objectName.StartsWith("promotions/", StringComparison.Ordinal)) return;
        await SendAsync(Req(HttpMethod.Delete,
            $"/storage/v1/object/{CatalogImagesBucket}/{objectName}", DbKey));
    }

    // =====================================================================
    //  PROFILE
    // =====================================================================
    /// <summary>Looks up a profile by email (case-insensitive).</summary>
    public async Task<Profile?> GetProfileByEmailAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email)) return null;

        var row = await SelectOneAsync<ProfileRow>("profiles",
            $"select=id,full_name,email,phone,role_id,photo_url,branch,created_at&email=ilike.{Q(email.Trim())}");
        return row == null ? null : ToProfile(row, await RolesAsync());
    }

    public async Task<Profile?> GetProfileByIdAsync(Guid profileId)
    {
        if (profileId == Guid.Empty) return null;
        var row = await SelectOneAsync<ProfileRow>("profiles",
            $"select=id,full_name,email,phone,role_id,photo_url,branch,created_at&id=eq.{profileId:D}");
        return row == null ? null : ToProfile(row, await RolesAsync());
    }

    /// <summary>Reads the auth-user email from the admin API.</summary>
    private async Task<string?> GetAuthUserEmailAsync(Guid userId)
    {
        var result = await SendAsync(Req(HttpMethod.Get,
            $"/auth/v1/admin/users/{userId:D}", DbKey));
        var authUser = JsonNode.Parse(result);
        return authUser?["email"]?.ToString();
    }

    /// <summary>
    /// Uploads a profile photo, updates profiles.photo_url, and rolls back the
    /// uploaded object if the DB update fails.
    /// </summary>
    public async Task<string> UploadProfilePhotoAsync(Guid profileId, IFormFile file, string folder = "managers")
    {
        if (folder is not ("managers" or "stylists" or "customers"))
            throw new ArgumentException("Invalid profile folder.", nameof(folder));
        if (file == null || file.Length == 0)
            throw new InvalidOperationException("Please choose a photo to upload.");
        if (file.Length > 2 * 1024 * 1024)
            throw new InvalidOperationException("The profile photo must be 2 MB or smaller.");

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png"))
            throw new InvalidOperationException("Please upload a JPG or PNG image.");

        await using var stream = new MemoryStream();
        await file.CopyToAsync(stream);
        var bytes = stream.ToArray();
        var isJpeg = bytes.Length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
        var isPng = bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(
            new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 });
        if (!(ext is ".jpg" or ".jpeg" ? isJpeg : isPng))
            throw new InvalidOperationException("The selected file isn't a valid JPG or PNG image.");

        var objectName = $"{folder}/{profileId:D}/{Guid.NewGuid():N}{(isJpeg ? ".jpg" : ".png")}";
        using var upload = Req(HttpMethod.Post,
            $"/storage/v1/object/{ProfilePhotoBucket}/{objectName}", DbKey);
        upload.Content = new ByteArrayContent(bytes);
        upload.Content.Headers.ContentType = new MediaTypeHeaderValue(isJpeg ? "image/jpeg" : "image/png");
        try
        {
            await SendAsync(upload);
        }
        catch (SupabaseException ex) when (ex.Status == HttpStatusCode.NotFound ||
                                            ex.Message.Contains("bucket", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "The catalog-images bucket is missing. Run Database/unified_images_reviews_schedule.sql in Supabase.", ex);
        }

        var publicUrl = $"{BaseUrl}/storage/v1/object/public/{ProfilePhotoBucket}/{objectName}";
        try
        {
            // Confirm the DB write actually persisted by asking Supabase to echo it back.
            var response = await SendAsync(Req(HttpMethod.Patch,
                $"/rest/v1/profiles?id=eq.{profileId:D}", DbKey,
                new { photo_url = publicUrl }, "return=representation"));
            var saved = JsonSerializer.Deserialize<List<ProfileRow>>(response, Json);
            if (saved?.Count != 1 || saved[0].Id != profileId || saved[0].PhotoUrl != publicUrl)
                throw new InvalidOperationException("Supabase did not confirm the manager's photo update.");
        }
        catch
        {
            // Roll back the just-uploaded object so storage doesn't accumulate orphans.
            try
            {
                await SendAsync(Req(HttpMethod.Delete,
                $"/storage/v1/object/{ProfilePhotoBucket}/{objectName}", DbKey));
            }
            catch { }
            throw;
        }

        Invalidate();
        return publicUrl;
    }

    /// <summary>
    /// Updates a manager profile. If the email changes, auth.users is updated
    /// first; on failure the profile update is rolled back to keep the two in sync.
    /// </summary>
    public async Task<Profile> UpdateProfileAsync(Profile profile)
    {
        var existing = await GetProfileByIdAsync(profile.Id)
            ?? throw new InvalidOperationException("Manager profile not found in Supabase.");
        if (!string.Equals(existing.Role, "Manager", StringComparison.OrdinalIgnoreCase))
            throw new UnauthorizedAccessException("Only manager profiles can be updated here.");

        var fullName = profile.FullName.Trim();
        var email = profile.Email.Trim().ToLowerInvariant();
        var phone = string.IsNullOrWhiteSpace(profile.Phone) ? null : profile.Phone.Trim();
        var branch = string.IsNullOrWhiteSpace(profile.Branch) ? null : profile.Branch.Trim();
        var emailChanged = !string.Equals(existing.Email.Trim(), email, StringComparison.OrdinalIgnoreCase);

        if (emailChanged)
        {
            // Guard against modifying a profile whose auth link is already broken.
            var authEmail = await GetAuthUserEmailAsync(profile.Id);
            if (!string.Equals(authEmail, existing.Email, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException(
                    "Your manager's Auth email does not match the profile email. " +
                    "Correct the account link in Supabase before changing the email.");
        }

        object updatedValues = new { full_name = fullName, email, phone, branch };
        var result = await SendAsync(Req(HttpMethod.Patch,
            $"/rest/v1/profiles?id=eq.{profile.Id:D}", DbKey,
            updatedValues, "return=representation"));
        var savedRows = JsonSerializer.Deserialize<List<ProfileRow>>(result, Json);
        if (savedRows?.Count != 1 || savedRows[0].Id != profile.Id)
            throw new InvalidOperationException("Supabase did not confirm saving your profile.");

        if (emailChanged)
        {
            try
            {
                await AdminUpdateUserAsync(profile.Id, new { email, email_confirm = true });
            }
            catch (Exception authError)
            {
                // Attempt to restore the original profile row.
                try
                {
                    await PatchAsync("profiles", $"id=eq.{profile.Id:D}", new
                    {
                        full_name = existing.FullName,
                        email = existing.Email,
                        phone = existing.Phone,
                        branch = existing.Branch
                    });
                }
                catch (Exception rollbackError)
                {
                    throw new InvalidOperationException(
                        "Supabase Auth rejected the email change, and restoring the original profile also failed. " +
                        "An administrator must reconcile public.profiles and auth.users before trying again.",
                        new AggregateException(authError, rollbackError));
                }
                throw new InvalidOperationException(
                    "Supabase Auth rejected the new email. Your original profile values were restored.", authError);
            }
        }

        Invalidate();
        // Read-back check: verify Supabase returned exactly what we wrote.
        var verified = await GetProfileByIdAsync(profile.Id)
            ?? throw new InvalidOperationException("Cannot reload the updated manager profile.");
        if (verified.FullName != fullName ||
            !string.Equals(verified.Email, email, StringComparison.OrdinalIgnoreCase) ||
            verified.Phone != phone || verified.Branch != branch)
            throw new InvalidOperationException(
                "Supabase returned different profile values after saving. Please refresh and verify the stored record.");
        return verified;
    }

    // =====================================================================
    // CUSTOMER ENQUIRIES / COMPLAINTS
    // =====================================================================

    /// <summary>Loads recent customer enquiries (up to 300) with customer names populated.</summary>
    public async Task<List<CustomerEnquiry>> GetCustomerEnquiriesAsync()
    {
        var records = await SelectAsync<CustomerEnquiry>("customer_enquiries",
            "select=*&order=created_at.desc&limit=300");

        // Per-call customer cache so multiple enquiries from the same customer use one lookup.
        var customerCache = new Dictionary<Guid, Profile?>();
        foreach (var enquiry in records)
        {
            if (!customerCache.TryGetValue(enquiry.CustomerId, out var customer))
            {
                customer = await GetProfileByIdAsync(enquiry.CustomerId);
                customerCache[enquiry.CustomerId] = customer;
            }
            enquiry.CustomerName = customer?.FullName ?? "Customer";
            enquiry.CustomerEmail = customer?.Email ?? "";
        }
        return records;
    }

    public async Task<CustomerEnquiry?> GetCustomerEnquiryAsync(long enquiryId)
    {
        if (enquiryId <= 0) return null;
        var enquiry = await SelectOneAsync<CustomerEnquiry>("customer_enquiries",
            $"select=*&enquiry_id=eq.{enquiryId}");
        if (enquiry == null) return null;
        var customer = await GetProfileByIdAsync(enquiry.CustomerId);
        enquiry.CustomerName = customer?.FullName ?? "Customer";
        enquiry.CustomerEmail = customer?.Email ?? "";
        return enquiry;
    }

    /// <summary>
    /// Records a manager reply via the manager_reply_to_customer_enquiry RPC.
    /// Returns false when the enquiry was already answered.
    /// </summary>
    public async Task<bool> ReplyToCustomerEnquiryAsync(
        long enquiryId, Guid managerId, string reply)
    {
        if (enquiryId <= 0 || managerId == Guid.Empty)
            throw new ArgumentException("Invalid enquiry or manager account.");
        if (string.IsNullOrWhiteSpace(reply) || reply.Trim().Length > 5000)
            throw new ArgumentException("Reply must be between 1 and 5,000 characters.");

        var response = await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/manager_reply_to_customer_enquiry", DbKey, new
            {
                p_enquiry_id = enquiryId,
                p_manager_id = managerId,
                p_reply = reply.Trim()
            }));
        return JsonSerializer.Deserialize<bool>(response, Json);
    }

    // =====================================================================
    // STYLIST LEAVE / BLOCK-DATE REQUESTS
    // =====================================================================

    /// <summary>
    /// Loads pending leave/block requests, groups them by GroupId, and tries to
    /// match each group to the corresponding customer_enquiries row so managers
    /// can navigate straight to the review page.
    /// </summary>
    public async Task<List<LeaveRequestGroup>> GetPendingLeaveRequestGroupsAsync()
    {
        List<StylistLeaveRequest> rows;
        try
        {
            rows = await SelectAsync<StylistLeaveRequest>("stylist_leave_requests",
                "select=*&status=eq.pending&order=created_at.desc,requested_date&limit=500");
        }
        catch (SupabaseException ex) when (IsMissingTable(ex))
        {
            return new List<LeaveRequestGroup>();
        }
        if (rows.Count == 0) return new List<LeaveRequestGroup>();

        var stylists = await StylistsAsync();
        foreach (var r in rows)
            r.StylistName = stylists.FirstOrDefault(s => s.StylistId == r.StylistId)
                ?.Profile?.FullName ?? $"Stylist {r.StylistId}";

        var groups = rows
            .GroupBy(r => r.GroupId)
            .Select(g => new LeaveRequestGroup
            {
                GroupId = g.Key,
                EnquiryId = 0,
                StylistId = g.First().StylistId,
                StylistName = g.First().StylistName,
                RequestType = g.First().RequestType,
                Reason = g.First().Reason,
                FirstDate = g.Min(x => x.RequestedDate),
                LastDate = g.Max(x => x.RequestedDate),
                DayCount = g.Count(),
                CreatedAt = g.Min(x => x.CreatedAt),
                Items = g.OrderBy(x => x.RequestedDate).ToList()
            })
            .OrderBy(g => g.FirstDate)
            .ToList();

        // The original SQL creates an enquiry but does not store its ID on each
        // leave row. Match the enquiry by stylist and exact date range so Review
        // links work even before the optional enquiry_id column is added.
        try
        {
            var enquiries = await GetCustomerEnquiriesAsync();
            foreach (var group in groups)
            {
                var start = group.FirstDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                var end = group.LastDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                var marker = $"Stylist ID: {group.StylistId} |";
                var range = $"Dates: {start} to {end} |";
                var match = enquiries.FirstOrDefault(e =>
                    e.Category == "stylist_leave_request" &&
                    e.Message.Contains(marker, StringComparison.OrdinalIgnoreCase) &&
                    e.Message.Contains(range, StringComparison.OrdinalIgnoreCase));
                group.EnquiryId = match?.EnquiryId ?? 0;
            }
        }
        catch (Exception ex)
        {
            // Keep schedule/enquiries pages usable; requests still appear even
            // if matching the enquiry card temporarily fails.
            _ = ex;
        }

        return groups;
    }

    /// <summary>Pending leave groups filtered to a single stylist.</summary>
    public async Task<List<LeaveRequestGroup>> GetPendingLeaveRequestGroupsForStylistAsync(long stylistId)
    {
        var all = await GetPendingLeaveRequestGroupsAsync();
        return all.Where(g => g.StylistId == stylistId).ToList();
    }

    /// <summary>
    /// Approves or rejects a leave group via the ce_review_stylist_leave RPC.
    /// A manager note (≤1000 chars) is required.
    /// </summary>
    public async Task ReviewLeaveRequestGroupAsync(Guid groupId, bool approve, string managerNote)
    {
        if (groupId == Guid.Empty)
            throw new ArgumentException("Invalid leave request group.", nameof(groupId));
        if (string.IsNullOrWhiteSpace(managerNote) || managerNote.Trim().Length > 1000)
            throw new ArgumentException("A decision note (up to 1,000 characters) is required.");

        await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/ce_review_stylist_leave", DbKey,
            new
            {
                p_group_id = groupId,
                p_approve = approve,
                p_manager_note = managerNote.Trim()
            }));
    }
}