namespace CuttingEdge.ManagerPortal.ViewModels;

public class ReviewSummary
{
    public double AverageRating { get; set; }
    public int TotalReviews { get; set; }
    public int NeedsFollowUp { get; set; }
}

public class ReportData
{
    public string Period { get; set; } = "monthly";
    public string PeriodLabel { get; set; } = string.Empty;
    public int CompletedBookings { get; set; }
    public int Cancelled { get; set; }
    public decimal CashRevenue { get; set; }
    public decimal CardRevenue { get; set; }
    public decimal TotalRevenue => CashRevenue + CardRevenue;
    public int CashPercent => TotalRevenue == 0 ? 0 : (int)Math.Round(CashRevenue / TotalRevenue * 100);
    public int CardPercent => TotalRevenue == 0 ? 0 : 100 - CashPercent;
}
