using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Authentication.Cookies;
using Supabase;

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// 1. SERVICES
// ============================================================

builder.Services.AddControllersWithViews();
builder.Services.AddHttpContextAccessor();

// Session
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromHours(8);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.Name = ".CuttingEdge.Session";
});

// Cookie Authentication
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.AccessDeniedPath = "/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromHours(2);
        options.SlidingExpiration = true;
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.Name = ".CuttingEdge.Auth";
    });

builder.Services.AddAuthorization();

// Supabase Client
builder.Services.AddScoped<Supabase.Client>(_ =>
{
    var url = builder.Configuration["Supabase:Url"];
    var key = builder.Configuration["Supabase:AnonKey"];

    if (string.IsNullOrEmpty(url) || string.IsNullOrEmpty(key))
        throw new InvalidOperationException(
            "Supabase Url and AnonKey must be configured in appsettings.json");

    var options = new SupabaseOptions
    {
        AutoRefreshToken = true,
        AutoConnectRealtime = false
    };

    return new Supabase.Client(url, key, options);
});

// Application Services
builder.Services.AddScoped<SupabaseService>();

var app = builder.Build();

// ============================================================
// 2. MIDDLEWARE
// ============================================================

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

app.UseSession();

app.UseAuthentication();
app.UseAuthorization();

// Prevent back-button caching of protected pages
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? "";

    if (!path.StartsWith("/css") &&
        !path.StartsWith("/js") &&
        !path.StartsWith("/images") &&
        !path.StartsWith("/lib") &&
        !path.StartsWith("/favicon"))
    {
        context.Response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
        context.Response.Headers["Pragma"] = "no-cache";
        context.Response.Headers["Expires"] = "0";
    }

    await next();
});

// ============================================================
// 3. AUTH GATE
// ============================================================
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value?.ToLower() ?? "";

    var isPublicPath =
        path.StartsWith("/account/login") ||
        path.StartsWith("/account/forgotpassword") ||
        path.StartsWith("/account/resetpassword") ||
        path.StartsWith("/home/privacy") ||
        path.StartsWith("/home/error") ||
        path.StartsWith("/home/welcome") ||          // ← ADDED
        path == "/" ||
        path.StartsWith("/css") ||
        path.StartsWith("/js") ||
        path.StartsWith("/images") ||
        path.StartsWith("/lib") ||
        path.StartsWith("/favicon");

    if (!isPublicPath)
    {
        var userEmail = context.Session.GetString("UserEmail");
        var hasAuthCookie = context.User?.Identity?.IsAuthenticated ?? false;

        if (string.IsNullOrEmpty(userEmail) && !hasAuthCookie)
        {
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

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();