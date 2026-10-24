// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CuttingEdge.ManagerPortal.Services;

// Runs while the manager portal is online. In Supabase enable pg_cron for
// independent expiry when this web application is not running.
/// <summary>
/// Background service that periodically expires overdue bookings.
/// The timer fires once per minute; the actual database update is performed
/// by a Supabase stored procedure (expire_overdue_bookings).
/// </summary>
public sealed class OverdueBookingsWorker : BackgroundService
{
    // Factory used to create a DI scope on each tick, so the short-lived
    // SupabaseService gets a fresh context and resources are released.
    private readonly IServiceScopeFactory _scopes;
    private readonly ILogger<OverdueBookingsWorker> _logger;

    public OverdueBookingsWorker(IServiceScopeFactory scopes, ILogger<OverdueBookingsWorker> logger)
    {
        _scopes = scopes;
        _logger = logger;
    }

    // Runs the expiry loop until the host requests shutdown
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Fire every minute; the first tick happens after one minute.
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        do
        {
            try
            {
                // Resolve SupabaseService from a fresh scope for this iteration only.
                using var scope = _scopes.CreateScope();
                await scope.ServiceProvider.GetRequiredService<SupabaseService>()
                    .ExpireOverdueBookingsAsync();
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                // Log but don't crash the loop — likely the SQL rule script
                // hasn't been applied yet, or Supabase was briefly unreachable.
                _logger.LogWarning(ex,
                    "Automatic cancellation did not run. Ensure Database/catalog_and_booking_rules.sql has been applied to Supabase.");
            }
        }

        // WaitForNextTickAsync throws OperationCanceledException on shutdown,
        // which BackgroundService handles gracefully.
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
