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

namespace CuttingEdge.ManagerPortal.ViewModels;
// Aggregated metrics shown as cards at the top of the manager dashboard.

public class DashboardMetrics
{
    public int TodayBookings { get; set; } // Number of bookings scheduled for today (non-cancelled).
    public int Cancelled { get; set; } // Number of cancellations recorded today.
    public decimal EstimatedRevenue { get; set; } // Estimated revenue for today (sum of service prices of today's bookings).
    public double AverageRating { get; set; }   // Average rating across all reviews (rounded to 1 decimal).
}


// Top-level model for the dashboard Index view, bundling metrics
public class DashboardViewModel
{
    // Summary card values.
    public DashboardMetrics Metrics { get; set; } = new(); 
    public List<Booking> TodayBookings { get; set; } = new(); // Today's bookings, hydrated with Customer/Stylist/Service navigation.
    public List<Review> RecentReviews { get; set; } = new(); // Most recent reviews (typically 5) shown in a side panel.
}