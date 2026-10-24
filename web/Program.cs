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

using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Authentication.Cookies;

// Application entry point. Builds the DI container, configures middleware
// pipeline (auth, caching, rate-limiting), and starts the Kestrel server.

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// 0. VALIDATE CONFIGURATION (Fails fast if keys are missing)
// ============================================================
// Read Supabase settings once. If any required value is absent or a
// placeholder ("sb_secret_" with no actual value), throw immediately —
// better to fail at startup than at the first request.

var supabaseUrl = builder.Configuration["Supabase:Url"];
var supabaseAnonKey = builder.Configuration["Supabase:AnonKey"];
var supabaseServiceKey = builder.Configuration["Supabase:ServiceRoleKey"];

if (string.IsNullOrWhiteSpace(supabaseUrl) || 
    string.IsNullOrWhiteSpace(supabaseAnonKey) || 
    supabaseServiceKey == "sb_secret_" || string.IsNullOrWhiteSpace(supabaseServiceKey))
{
    throw new Exception("FATAL ERROR: Supabase configuration is missing or invalid. Check appsettings.json.");
}

// ============================================================
// 1. SERVICES
// ============================================================
// MVC controllers + Razor views.
builder.Services.AddControllersWithViews();
builder.Services.AddHttpContextAccessor(); // Required for SupabaseService to access the current HttpContext (session, user).

// Session
// Distributed memory cache backs the session store. In-process only,
// so sessions are lost on app restart — acceptable for a single-node deployment.
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    // 8-hour idle timeout matches a typical manager workday
    options.IdleTimeout = TimeSpan.FromHours(8); // HttpOnly: JS cannot read the session cookie (mitigates XSS token theft)
    options.Cookie.HttpOnly = true;
    // IsEssential: the cookie is exempt from GDPR consent requirements
    // because it's required for the app to function
    options.Cookie.IsEssential = true;
    options.Cookie.Name = ".CuttingEdge.Session";
});

// Cookie Authentication
// Cookie is the single auth scheme; LoginPath/AccessDeniedPath redirect
// unauthenticated users to the login page.
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.AccessDeniedPath = "/Account/Login"; // Shorter than session: 2 hours forces re-auth more often than the session expires.
        options.ExpireTimeSpan = TimeSpan.FromHours(2); // Renew the expiry while the user is active.
        options.SlidingExpiration = true;
        options.Cookie.HttpOnly = true; // Lax: cookie is sent on same-site navigation but not on cross-site POSTs.
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.Name = ".CuttingEdge.Auth";
    });

// AuthorizeAttribute evaluation; needed even without explicit global policies.
builder.Services.AddAuthorization();

// Limits OTP requests and guesses per network address.
// Two named policies are referenced by [EnableRateLimiting(...)] on the
// ForgotPassword (send) and ForgotPasswordConfirmation (verify) actions.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("recovery-send", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(10),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
    options.AddPolicy("recovery-verify", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(10),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

// Supabase Services
builder.Services.AddHttpClient();
builder.Services.AddScoped<SupabaseService>();
builder.Services.AddHostedService<OverdueBookingsWorker>();

var app = builder.Build();

// ============================================================
// 2. MIDDLEWARE
// ============================================================
// Development vs production error handling: pretty exception page in dev,
// safe "Home/Error" page + HSTS in production.

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}
else
{
    app.UseDeveloperExceptionPage();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();

app.UseSession(); // Required for HttpContext.Session to be usable downstream (controllers, service).

// Auth must run after Session (auth gate below reads session values).
app.UseAuthentication();
app.UseAuthorization();

// Prevent back-button caching of protected pages
// Emits no-cache headers on all HTML routes so the browser doesn't serve a
// stale logged-in page after logout. Static assets are excluded so they can
// still be cached by the browser/CDN.
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? "";

    if (!path.StartsWith("/css") &&
        !path.StartsWith("/js") &&
        !path.StartsWith("/images") &&
        !path.StartsWith("/lib") &&
        !path.StartsWith("/favicon"))
    {
        context.Response.Headers.CacheControl = "no-cache, no-store, must-revalidate";
        context.Response.Headers.Pragma = "no-cache";
        context.Response.Headers.Expires = "0";
    }

    await next();
});

// ============================================================
// 3. AUTH GATE
// ============================================================
// Second layer of auth defence: even before controller attributes run,
// unauthenticated users are bounced to Login with the original URL preserved.
// This catches direct navigation to protected pages that lack [Authorize].
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value?.ToLower() ?? "";
    // Whitelist: pages that must be reachable without authentication,
    // plus static assets and health/error endpoints.

    var isPublicPath =
        path.StartsWith("/account/login") ||
        path.StartsWith("/account/forgotpassword") ||
        path.StartsWith("/account/resetpassword") ||
        path.StartsWith("/account/acceptstylistinvite") ||
        path.StartsWith("/home/privacy") ||
        path.StartsWith("/home/error") ||
        path.StartsWith("/home/welcome") ||          
        path == "/" ||
        path.StartsWith("/css") ||
        path.StartsWith("/js") ||
        path.StartsWith("/images") ||
        path.StartsWith("/lib") ||
        path.StartsWith("/favicon");

    if (!isPublicPath)
    {
        // Either a valid session "UserEmail" OR an authenticated cookie
        // is considered sufficient to proceed. Controllers still re-check
        // roles/claims on their own for defence-in-depth.
        var userEmail = context.Session.GetString("UserEmail");
        var hasAuthCookie = context.User?.Identity?.IsAuthenticated ?? false;

        if (string.IsNullOrEmpty(userEmail) && !hasAuthCookie)
        {
            // Preserve the intended destination so the user lands there
            // after login (validated by Url.IsLocalUrl inside AccountController).
            var returnUrl = context.Request.Path + context.Request.QueryString;
            context.Response.Redirect($"/Account/Login?returnUrl={Uri.EscapeDataString(returnUrl)}");
            return;
        }
    }

    await next();
});

// ============================================================
// 4. ROUTES
// ============================================================
// Conventional MVC routing: /{controller}/{action}/{id?}
// Defaults to Home/Index so the bare domain loads the welcome page.

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();