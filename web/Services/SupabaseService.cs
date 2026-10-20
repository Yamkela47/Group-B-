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

public class AuthUser
{
    public Guid Id { get; set; }
    public string? Email { get; set; }
}

public class AuthSession
{
    public string? AccessToken { get; set; }
    public AuthUser? User { get; set; }
}

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

public class SupabaseService
{
    private const string GalleryBucket = "catalog-images";
    private const string CatalogImagesBucket = "catalog-images";
    private const string ProfilePhotoBucket = "catalog-images";
    private const int ScheduleDays = 56;
    private const int ScheduleReadDays = 14;

    private static readonly string[] Days =
        { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" };

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

    private HttpRequestMessage Req(HttpMethod method, string path, string key, object? body = null, string? prefer = null)
    {
        var req = new HttpRequestMessage(method, BaseUrl + path);
        req.Headers.TryAddWithoutValidation("apikey", key);
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

    private static bool IsMissingTable(SupabaseException ex) =>
        ex.Code is "PGRST205" or "42P01" || ex.Status == HttpStatusCode.NotFound;

    private static string RestPath(string table, string query) =>
        "/rest/v1/" + table + (string.IsNullOrEmpty(query) ? "" : "?" + query);

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

    private static string DateStr(DateTime d) => d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    private static string TimeStr(TimeSpan t) => t.ToString(@"hh\:mm\:ss", CultureInfo.InvariantCulture);
    private static string Q(string s) => Uri.EscapeDataString(s);

    private static string InList<TItem>(IEnumerable<TItem> items) =>
        "(" + string.Join(",", items.Select(i => Convert.ToString(i, CultureInfo.InvariantCulture))) + ")";

    private static string Iso(DateTime localTime) =>
        Uri.EscapeDataString(new DateTimeOffset(DateTime.SpecifyKind(localTime, DateTimeKind.Local)).ToString("o"));

    private static string ToAppStatus(string? dbStatus)
    {
        if (string.Equals(dbStatus, "completed", StringComparison.OrdinalIgnoreCase)) return "Completed";
        if (string.Equals(dbStatus, "cancelled", StringComparison.OrdinalIgnoreCase)) return "Cancelled";
        return "Incomplete";
    }

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
        public DateTime? CreatedAt { get; set; }
    }

    private async Task<List<RoleRow>> RolesAsync() =>
        _roles ??= await SelectAsync<RoleRow>("roles", "select=role_id,role_name");

    private async Task<long> RoleIdAsync(string roleName)
    {
        var role = (await RolesAsync()).FirstOrDefault(r => r.RoleName.Equals(roleName, StringComparison.OrdinalIgnoreCase));
        return role?.RoleId ?? throw new InvalidOperationException($"The '{roleName}' role is missing from the roles table.");
    }

    private static Profile ToProfile(ProfileRow r, List<RoleRow> roles) => new()
    {
        Id = r.Id,
        FullName = r.FullName ?? "",
        Email = r.Email ?? "",
        Phone = r.Phone,
        Role = roles.FirstOrDefault(x => x.RoleId == r.RoleId)?.RoleName ?? "Customer",
        PhotoUrl = r.PhotoUrl,
        CreatedAt = r.CreatedAt ?? DateTime.MinValue
    };

    private async Task<Dictionary<Guid, Profile>> ProfilesAsync(IEnumerable<Guid> ids)
    {
        var missing = ids.Distinct().Where(i => !_profiles.ContainsKey(i)).ToList();
        if (missing.Count > 0)
        {
            var roles = await RolesAsync();
            foreach (var chunk in missing.Chunk(50))
            {
                var rows = await SelectAsync<ProfileRow>("profiles",
                    $"select=id,full_name,email,phone,role_id,photo_url,created_at&id=in.{InList(chunk)}");
                foreach (var r in rows) _profiles[r.Id] = ToProfile(r, roles);
            }
        }
        return _profiles;
    }

    private async Task<List<Stylist>> StylistsAsync()
    {
        if (_stylists != null) return _stylists;
        var list = await SelectAsync<Stylist>("stylists", "select=*&order=stylist_id");
        var profiles = await ProfilesAsync(list.Select(s => s.ProfileId));
        foreach (var s in list) s.Profile = profiles.GetValueOrDefault(s.ProfileId);
        return _stylists = list;
    }

    private async Task<List<Service>> ServicesAsync() =>
        _services ??= await SelectAsync<Service>("services", "select=*&order=name");

    private async Task<List<PaymentMethod>> PaymentsAsync() =>
        _payments ??= await SelectAsync<PaymentMethod>("payment_methods", "select=*");

    private void Invalidate()
    {
        _stylists = null;
        _services = null;
        _payments = null;
        _profiles.Clear();
    }

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

    private async Task HydrateAsync(List<Review> reviews)
    {
        if (reviews.Count == 0) return;
        var profiles = await ProfilesAsync(reviews.Select(r => r.CustomerId));
        var stylists = await StylistsAsync();

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

    private async Task HydrateAsync(List<Promotion> promotions)
    {
        var services = await ServicesAsync();
        foreach (var p in promotions)
            p.Service = services.FirstOrDefault(s => s.ServiceId == p.ServiceId);
    }

    private string? CurrentEmail => _ctx.HttpContext?.Session.GetString("UserEmail");

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

    public Task SignOutAsync() => Task.CompletedTask;

    public async Task SendPasswordResetEmailAsync(string email)
    {
        var redirect = _config["Supabase:SiteUrl"];
        if (string.IsNullOrWhiteSpace(redirect))
        {
            var r = _ctx.HttpContext?.Request;
            redirect = r == null ? "" : $"{r.Scheme}://{r.Host}";
        }
        redirect = redirect.TrimEnd('/') + "/Account/ResetPassword";

        var path = "/auth/v1/recover?redirect_to=" + Q(redirect);
        await SendAsync(Req(HttpMethod.Post, path, AnonKey, new { email = email.Trim() }));
    }

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

    public async Task ChangePasswordAsync(string currentPassword, string newPassword)
    {
        var email = CurrentEmail ?? throw new InvalidOperationException("You're not signed in.");
        var session = await SignInAsync(email, currentPassword);
        if (session?.User == null) throw new InvalidOperationException("Your current password is incorrect.");
        await AdminUpdateUserAsync(session.User.Id, new { password = newPassword });
    }

    private async Task AdminUpdateUserAsync(Guid userId, object attributes) =>
        await SendAsync(Req(HttpMethod.Put, $"/auth/v1/admin/users/{userId}", DbKey, attributes));

    // Supabase Auth sends a real invitation e-mail. The invite opens a public
    // password-creation page, not the manager-only login page.
    private async Task<Guid> InviteStylistAsync(string email, string fullName)
    {
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

    // Create a confirmed Supabase Auth account when the manager supplies an
    // initial password. This is a server-side admin call, never a Flutter call.
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

    private async Task AdminDeleteUserAsync(Guid userId) =>
        await SendAsync(Req(HttpMethod.Delete, $"/auth/v1/admin/users/{userId}", DbKey));

    // =====================================================================
    //  E-MAIL
    // =====================================================================
    public async Task SendEmailAsync(string to, string subject, string body)
    {
        var host = _config["Email:SmtpHost"];
        var user = _config["Email:SmtpUser"];
        var pass = _config["Email:SmtpPass"];
        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(user) ||
            string.IsNullOrWhiteSpace(pass) || pass.StartsWith("your-"))
            throw new InvalidOperationException(
                "E-mail isn't set up yet. Add Email:SmtpUser and Email:SmtpPass to your configuration.");

        var port = int.TryParse(_config["Email:SmtpPort"], out var p) ? p : 587;

        try
        {
            var from = new MailAddress(_config["Email:FromEmail"] ?? user, _config["Email:FromName"] ?? "Cutting Edge Salon");
            using var msg = new MailMessage(from, new MailAddress(to)) { Subject = subject, Body = body };
            using var smtp = new SmtpClient(host, port)
            {
                EnableSsl = true,
                Credentials = new NetworkCredential(user, pass)
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

    public async Task<List<Booking>> GetTodayBookingsAsync()
    {
        var list = await SelectAsync<Booking>("bookings",
            $"select=*&appointment_date=eq.{DateStr(DateTime.Today)}&status=neq.cancelled&order=start_time");
        await HydrateAsync(list);
        return list;
    }

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
    public async Task<List<Booking>> GetFilteredBookingsAsync(string? status, string? date, string? search)
    {
        var filters = new List<string> { "select=*" };

        if (string.Equals(status, "Completed", StringComparison.OrdinalIgnoreCase)) filters.Add("status=eq.completed");
        else if (string.Equals(status, "Incomplete", StringComparison.OrdinalIgnoreCase)) filters.Add("status=in.(pending,confirmed,booked,incomplete)");
        else if (string.Equals(status, "Cancelled", StringComparison.OrdinalIgnoreCase)) filters.Add("status=eq.cancelled");

        if (DateTime.TryParse(date, out var d)) filters.Add($"appointment_date=eq.{DateStr(d)}");

        filters.Add("order=appointment_date.desc,start_time.asc");
        filters.Add("limit=1000");

        var list = await SelectAsync<Booking>("bookings", string.Join("&", filters));
        await HydrateAsync(list);
        await HydrateCancellationsAsync(list);

        if (!string.IsNullOrWhiteSpace(search))
            list = list.Where(b =>
                (b.Customer?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (b.Service?.Name ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (b.Stylist?.Profile?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase)).ToList();

        return list;
    }

    public async Task<Booking?> GetBookingByIdAsync(long id)
    {
        var b = await SelectOneAsync<Booking>("bookings", $"select=*&booking_id=eq.{id}");
        if (b == null) return null;
        await HydrateAsync(new List<Booking> { b });
        await HydrateCancellationsAsync(new List<Booking> { b });
        return b;
    }

    private async Task HydrateCancellationsAsync(List<Booking> bookings)
    {
        var cancelled = bookings.Where(b => b.Status == "Cancelled").ToList();
        if (cancelled.Count == 0) return;

        var records = new List<Cancellation>();
        foreach (var ids in cancelled.Select(b => b.BookingId).Distinct().Chunk(75))
            records.AddRange(await SelectAsync<Cancellation>("cancellations",
                $"select=*&booking_id=in.{InList(ids)}&order=cancelled_at.desc"));

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
                record.CancelledActor = record.CancelledBy;
            }
        }
    }

    public async Task UpdateBookingStatusAsync(long id, string status)
    {
        var current = await GetBookingByIdAsync(id)
            ?? throw new InvalidOperationException("Booking not found.");
        if (current.Status is "Completed" or "Cancelled")
            throw new InvalidOperationException("A completed or cancelled booking cannot change status.");
        if (status != "Completed")
            throw new InvalidOperationException("Use the cancellation action to cancel bookings with a reason.");
        var completed = await SendAsync(Req(HttpMethod.Patch,
            RestPath("bookings", $"booking_id=eq.{id}&status=in.(pending,confirmed,booked,incomplete)"),
            DbKey, new { status = "completed" }, "return=representation"));
        if ((JsonNode.Parse(completed) as JsonArray)?.Count != 1)
            throw new InvalidOperationException("Booking has already been completed or cancelled.");
    }

    // Calls a SECURITY DEFINER Supabase function, so expiry and reason are recorded atomically.
    // Called by the background service while the portal is running. Supabase pg_cron can
    // call the same function when the website is offline (see database migration).
    public async Task ExpireOverdueBookingsAsync()
    {
        await SendAsync(Req(HttpMethod.Post,
            "/rest/v1/rpc/expire_overdue_bookings", DbKey, new { }));
    }

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

        // Requires Database/manager_booking_actions.sql. One transaction records
        // the booking status, actor role/name, and cancellation reason.
        await SendAsync(Req(HttpMethod.Post, "/rest/v1/rpc/cancel_booking_by_manager",
            DbKey, new
            {
                p_booking_id = id,
                p_reason = reason.Trim(),
                p_manager_name = string.IsNullOrWhiteSpace(managerName) ? "Manager" : managerName.Trim()
            }));
        try
        {
            await CreateNotificationAsync(booking.CustomerId, "Booking cancelled",
                $"The salon cancelled your appointment. Reason: {reason.Trim()}", "Booking");
            if (booking.Stylist != null)
                await CreateNotificationAsync(booking.Stylist.ProfileId, "Appointment cancelled",
                    $"A booking on {booking.AppointmentDate:dd MMM yyyy} was cancelled by the manager. Reason: {reason.Trim()}", "Booking");
        }
        catch { /* Notification delivery must not undo the database transaction. */ }
    }

    // Duration is always calculated from the saved service, never from browser input.
    // The database RPC independently verifies duration, shift, leave and conflicts.
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
        if (date.Date.Add(start) <= DateTime.UtcNow.AddHours(2))
            throw new InvalidOperationException("Choose a future date and start time (South African time).");

        // The THREE-argument RPC recomputes the end time in PostgreSQL too.
        await SendAsync(Req(HttpMethod.Post, "/rest/v1/rpc/manager_reschedule_booking",
            DbKey, new
            {
                p_booking_id = id,
                p_appointment_date = DateStr(date),
                p_start_time = TimeStr(start)
            }));
        return end;
    }

    public async Task CreateNotificationAsync(Guid profileId, string title, string message, string? type = null) =>
        await InsertAsync("notifications", new
        {
            profile_id = profileId,
            title,
            message,
            notification_type = type,
            is_read = false
        });

    public async Task CreateCancellationRecordAsync(long bookingId, string reason) =>
        await UpsertAsync("cancellations", "booking_id", new { booking_id = bookingId, reason });

    public async Task UpdateBookingAsync(Booking booking)
    {
        var current = await SelectOneAsync<Booking>("bookings", $"select=booking_id,status,appointment_date,start_time,end_time&booking_id=eq.{booking.BookingId}");
        if (current?.Status is "completed" or "cancelled")
            throw new InvalidOperationException("Completed and cancelled bookings cannot be rescheduled or edited.");
        var dbStatus = ToDbStatus(booking.Status);
        // An active booking is already accepted once created. Preserve its
        // stored status instead of silently promoting it to 'confirmed'.
        if (dbStatus == "confirmed" && current != null &&
            (current.Status == "pending" || current.Status == "confirmed" ||
             current.Status == "booked" || current.Status == "incomplete"))
            dbStatus = current.Status;

        // Keep edits in sync with the same overlap and date validation used
        // by the dedicated Reschedule form.
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

    public Task DeleteBookingAsync(long id, string reason) =>
        CancelBookingByManagerAsync(id, reason);

    // =====================================================================
    //  STYLISTS
    // =====================================================================
    public async Task<List<Stylist>> GetAllStylistsWithProfilesAsync() =>
        (await StylistsAsync()).OrderByDescending(s => s.Active).ThenBy(s => s.Profile?.FullName).ToList();

    public async Task<Stylist?> GetStylistByIdAsync(long id) =>
        (await StylistsAsync()).FirstOrDefault(s => s.StylistId == id);

    private class StylistServiceRow
    {
        public long StylistId { get; set; }
        public long ServiceId { get; set; }
    }

    // These three queries power the stylist Details page. They intentionally
    // read live data from the same tables shared with the Flutter app.
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

    public Task<List<StylistSchedule>> GetUpcomingScheduleForStylistAsync(long stylistId) =>
        SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&stylist_id=eq.{stylistId}&is_available=eq.true" +
            $"&work_date=gte.{DateStr(DateTime.Today)}&order=work_date.asc,start_time.asc&limit=56");

    private static string WorkingHoursSummary(Dictionary<string, DaySchedule> week)
    {
        var on = Days.Where(d => week.TryGetValue(d, out var s) && s.Enabled).ToList();
        if (on.Count == 0) return "Not scheduled";
        var first = week[on[0]];
        return string.Join(", ", on.Select(d => d[..3])) + $" · {first.StartTime} – {first.EndTime}";
    }

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

    public async Task CreateStylistAsync(StylistViewModel model)
    {
        var roleId = await RoleIdAsync("Stylist");
        if (string.IsNullOrWhiteSpace(model.Email) || string.IsNullOrWhiteSpace(model.FullName))
            throw new InvalidOperationException("A stylist name and email address are required.");

        // Supabase sends the invite as part of user creation; never create an
        // uninvited account with a password the stylist does not know.
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
            try { await AdminDeleteUserAsync(userId); } catch { }
            throw;
        }
        finally
        {
            Invalidate();
        }

    }

    public async Task UpdateStylistAsync(StylistViewModel model)
    {
        var stylist = await GetStylistByIdAsync(model.StylistId);
        if (stylist == null) return;

        var email = model.Email.Trim();
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

    // Manager-only workflow: update an existing stylist's Supabase Auth password.
    // No password is written to public.profiles or public.stylists.
    public async Task ResetStylistPasswordAsync(long stylistId, string newPassword)
    {
        if (string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 8 || newPassword.Length > 128)
            throw new ArgumentException("Password must contain between 8 and 128 characters.", nameof(newPassword));

        var stylist = await GetStylistByIdAsync(stylistId)
            ?? throw new InvalidOperationException("Stylist not found.");

        if (stylist.ProfileId == Guid.Empty)
            throw new InvalidOperationException("This stylist has no linked Supabase Auth ID.");

        // The stylist's public profile ID must also exist in auth.users.
        // Never use an email-based fallback to update a different account.
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

    private async Task SetStylistServicesAsync(long stylistId, IEnumerable<long> serviceIds)
    {
        await DeleteAsync("stylist_services", $"stylist_id=eq.{stylistId}");
        await InsertManyAsync("stylist_services",
            serviceIds.Distinct().Select(sid => (object)new { stylist_id = stylistId, service_id = sid }));
    }

    public async Task DeactivateStylistAsync(long id)
    {
        await PatchAsync("stylists", $"stylist_id=eq.{id}", new { active = false });
        Invalidate();
    }

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

        try { await AdminDeleteUserAsync(stylist.ProfileId); } catch (SupabaseException) { }
        try { await DeleteAsync("profiles", $"id=eq.{stylist.ProfileId}"); } catch (SupabaseException) { }
        Invalidate();
    }

    // =====================================================================
    //  SCHEDULES
    // =====================================================================
    private static Dictionary<string, DaySchedule> DefaultWeek() =>
        Days.ToDictionary(d => d, d => new DaySchedule
        {
            Enabled = d != "Sunday",
            StartTime = "09:00",
            EndTime = d == "Saturday" ? "15:00" : "17:00"
        });

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

    private async Task<List<StylistSchedule>> ScheduleRowsAsync(string stylistFilter)
    {
        var today = DateTime.Today;
        return await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&{stylistFilter}&work_date=gte.{DateStr(today)}&work_date=lt.{DateStr(today.AddDays(ScheduleReadDays))}&order=work_date");
    }

    public async Task<ScheduleCalendarViewModel> GetScheduleCalendarAsync(
        DateTime selectedMonth, long? selectedStylistId = null)
    {
        var first = new DateTime(selectedMonth.Year, selectedMonth.Month, 1);
        var after = first.AddMonths(1);
        var stylists = (await StylistsAsync()).Where(s => s.Active).ToList();
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

    /// <summary>
    /// Date-specific leave / sickness days declared by a stylist in Flutter.
    /// Uses the same blocked_dates table as the schedule calendar.
    /// The next six months are shown so the manager can inspect future leave.
    /// </summary>
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

    public async Task<List<Booking>> GetWeeklyBookingsByStylistAsync(long stylistId)
    {
        var monday = DateTime.Today.AddDays(-(((int)DateTime.Today.DayOfWeek + 6) % 7));
        var list = await SelectAsync<Booking>("bookings",
            $"select=*&stylist_id=eq.{stylistId}&status=in.(pending,confirmed,booked,incomplete)" +
            $"&appointment_date=gte.{DateStr(monday)}&appointment_date=lt.{DateStr(monday.AddDays(7))}" +
            "&order=appointment_date,start_time");
        await HydrateAsync(list);
        return list;
    }

    private async Task SaveWeekAsync(long stylistId, Dictionary<string, DaySchedule> week)
    {
        var today = DateTime.Today;
        var end = today.AddDays(ScheduleDays);

        var existing = await SelectAsync<StylistSchedule>("stylist_schedules",
            $"select=*&stylist_id=eq.{stylistId}&work_date=gte.{DateStr(today)}&work_date=lt.{DateStr(end)}&order=work_date");

        // Do not alter any day containing an active booking. Checking every date in
        // the 56-day range prevents a weekly-template edit from silently moving one.
        var activeBookings = await SelectAsync<Booking>("bookings",
            $"select=booking_id,appointment_date&stylist_id=eq.{stylistId}" +
            $"&appointment_date=gte.{DateStr(today)}&appointment_date=lt.{DateStr(end)}" +
            "&status=in.(pending,confirmed,booked,incomplete)");
        // Exclusions from Flutter are single dates, not a recurring weekday rule.
        // A weekly schedule save must never re-enable or recreate these shifts.
        var blockedRows = await SelectAsync<BlockedDate>("blocked_dates",
            $"select=id,stylist_id,blocked_date&stylist_id=eq.{stylistId}" +
            $"&blocked_date=gte.{DateStr(today)}&blocked_date=lt.{DateStr(end)}");
        var blockedDates = blockedRows.Select(x => x.Date.Date).ToHashSet();

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

            // A blocked date stays OFF regardless of the recurring weekday switch.
            // We keep the record and any shift rows, but mark existing shifts
            // unavailable. No shift is inserted for a blocked date.
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
                    // Restore availability if a former leave day has been
                    // unblocked in Flutter, while respecting current week hours.
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
                deleteIds.AddRange(rows.Where(r => r.IsAvailable).Select(r => r.ScheduleId));
            }
        }

        await InsertManyAsync("stylist_schedules", inserts);
        if (deleteIds.Count > 0)
            await DeleteAsync("stylist_schedules", $"schedule_id=in.{InList(deleteIds)}");
    }

    public Task SaveScheduleAsync(ScheduleViewModel model) => SaveWeekAsync(model.StylistId, model.WeekSchedule);

    public Task UpdateScheduleAsync(long stylistId, ScheduleViewModel model) => SaveWeekAsync(stylistId, model.WeekSchedule);

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

    // Only the ASP.NET manager backend writes to this audit table.
    public async Task<ReviewFollowUpRecord> GetReviewFollowUpAsync(Guid reviewId) =>
        await SelectOneAsync<ReviewFollowUpRecord>("review_followups",
            $"select=*&review_id=eq.{reviewId}")
        ?? new ReviewFollowUpRecord { ReviewId = reviewId };

    public async Task EnsureReviewFollowUpAsync(Guid reviewId)
    {
        var existing = await SelectOneAsync<ReviewFollowUpRecord>("review_followups",
            $"select=review_id&review_id=eq.{reviewId}");
        if (existing == null)
        {
            // If two browser requests race, the on_conflict upsert is safe.
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

    // Calls a manager-only Supabase function. Notification and follow-up history
    // are saved atomically; sending it again cannot create duplicate apologies.
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

    // Calls a manager-only Supabase function, which determines the recipient
    // from reviews.stylist_id -> stylists.profile_id (never from the browser).
    // Writing the notification and its follow-up record is one transaction.
    // false means the report was already sent, so no duplicate is created.
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

        // Include every booking in the date range for the detailed PDF table.
        // Paginate so a busy month isn't silently truncated by PostgREST limits.
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

        // Names and booking details come from the actual Supabase bookings,
        // profiles, stylists, services and payment_methods tables.
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
                // The system does not store payment transactions. For completed
                // appointments, the service price is the assumed paid amount;
                // uncompleted bookings have an unknown paid amount, not zero.
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

    public Task<byte[]> GenerateReportPdfAsync(ReportData report) =>
        Task.FromResult(ReportPdfBuilder.Build(report));

    // =====================================================================
    //  GALLERY
    // =====================================================================
    public Task<List<GalleryImage>> GetAllGalleryImagesAsync() =>
        SelectAsync<GalleryImage>("gallery_images", "select=*&order=created_at.desc");

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

    public async Task DeleteGalleryImageAsync(long id)
    {
        var image = await SelectOneAsync<GalleryImage>("gallery_images", $"select=*&image_id=eq.{id}");
        await DeleteAsync("gallery_images", $"image_id=eq.{id}");

        var url = image?.ImageUrl ?? "";
        // Delete from whichever bucket originally stored the picture.
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

    public async Task DeleteCatalogImageAsync(string? publicUrl)
    {
        if (string.IsNullOrWhiteSpace(publicUrl)) return;
        var prefix = $"{BaseUrl}/storage/v1/object/public/{CatalogImagesBucket}/";
        if (!publicUrl.StartsWith(prefix, StringComparison.Ordinal)) return;
        var objectName = publicUrl[prefix.Length..];
        if (!objectName.StartsWith("services/", StringComparison.Ordinal) &&
            !objectName.StartsWith("promotions/", StringComparison.Ordinal)) return;
        await SendAsync(Req(HttpMethod.Delete,
            $"/storage/v1/object/{CatalogImagesBucket}/{objectName}", DbKey));
    }

    // =====================================================================
    //  PROFILE
    // =====================================================================
    public async Task<Profile?> GetProfileByEmailAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email)) return null;

        var row = await SelectOneAsync<ProfileRow>("profiles",
            $"select=id,full_name,email,phone,role_id,photo_url,created_at&email=ilike.{Q(email.Trim())}");
        return row == null ? null : ToProfile(row, await RolesAsync());
    }

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

        // A unique filename also prevents browsers from displaying an older
        // cached avatar after an administrator replaces their photo.
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
            await PatchAsync("profiles", $"id=eq.{profileId}", new { photo_url = publicUrl });
        }
        catch
        {
            // Never leave a newly uploaded file orphaned when the DB update fails.
            try
            {
                await SendAsync(Req(HttpMethod.Delete,
                $"/storage/v1/object/{ProfilePhotoBucket}/{objectName}", DbKey));
            }
            catch { /* Preserve the original DB error. */ }
            throw;
        }

        Invalidate();
        return publicUrl;
    }

    public async Task UpdateProfileAsync(Profile profile)
    {
        var email = profile.Email.Trim();
        var existing = (await ProfilesAsync(new[] { profile.Id })).GetValueOrDefault(profile.Id);

        if (existing != null && !string.Equals(existing.Email, email, StringComparison.OrdinalIgnoreCase))
        {
            await AdminUpdateUserAsync(profile.Id, new { email, email_confirm = true });
            _ctx.HttpContext?.Session.SetString("UserEmail", email);
        }

        await PatchAsync("profiles", $"id=eq.{profile.Id}", new
        {
            full_name = profile.FullName,
            email,
            phone = profile.Phone
        });
        Invalidate();
    }
}
