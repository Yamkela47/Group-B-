using CuttingEdge.ManagerPortal.Models;

namespace CuttingEdge.ManagerPortal.ViewModels;

public class DashboardMetrics
{
    public int TodayBookings { get; set; }
    public int Cancelled { get; set; }
    public decimal EstimatedRevenue { get; set; }
}

public class DashboardViewModel
{
    public DashboardMetrics Metrics { get; set; } = new();
    public List<Booking> TodayBookings { get; set; } = new();
    public List<Review> RecentReviews { get; set; } = new();
}
