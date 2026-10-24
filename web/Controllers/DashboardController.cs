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

    //Loads dashboard data (metrics, today's bookings, recent reviews) and renders the Index view.
    //On failure, sets a TempData error and renders an empty view model so the page still loads.

    public async Task<IActionResult> Index()
    {
        try
        {
            // Fetch the three dashboard data sets in sequence from the service layer.
            var metrics = await _supabaseService.GetDashboardMetricsAsync();
            var todayBookings = await _supabaseService.GetTodayBookingsAsync();
            var recentReviews = await _supabaseService.GetRecentReviewsAsync(5);

            // Bundle everything the view needs into a single view model
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
            // Store the error for the view to display, then render an empty dashboard
            // so the page doesn't crash if Supabase is unavailable.
            TempData["Error"] = $"Error loading dashboard: {ex.Message}";
            return View(new DashboardViewModel());
        }
    }
}