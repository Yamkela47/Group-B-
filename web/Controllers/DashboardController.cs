using CuttingEdge.ManagerPortal.Models;
using CuttingEdge.ManagerPortal.Services;
using CuttingEdge.ManagerPortal.ViewModels;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class DashboardController : Controller
{
    private readonly SupabaseService _supabaseService;

    public DashboardController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Dashboard
    public async Task<IActionResult> Index()
    {
        try
        {
            var metrics = await _supabaseService.GetDashboardMetricsAsync();
            var todayBookings = await _supabaseService.GetTodayBookingsAsync();
            var recentReviews = await _supabaseService.GetRecentReviewsAsync(5);

            var viewModel = new DashboardViewModel
            {
                Metrics = metrics,
                TodayBookings = todayBookings,
                RecentReviews = recentReviews
            };

            return View(viewModel);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading dashboard: {ex.Message}";
            return View(new DashboardViewModel());
        }
    }
}