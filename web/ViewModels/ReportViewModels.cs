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

namespace CuttingEdge.ManagerPortal.ViewModels;
// Headline review statistics shown on the reviews/reports page

public class ReviewSummary
{
    public double AverageRating { get; set; }
    public int TotalReviews { get; set; }
    public int NeedsFollowUp { get; set; }
    public int ThisWeekCount { get; set; }
}


// One bar in the revenue chart: cash vs card totals for a bucket
// (a single day, or a full week for long report periods).
public class RevenueBar
{
    public string Label { get; set; } = "";
    public decimal Cash { get; set; }
    public decimal Card { get; set; }
}

// One row in the "Top services by demand" breakdown.
public class ServiceDemand
{
    public string Name { get; set; } = "";
    public int Count { get; set; }
    public int Percent { get; set; }
}


// Complete dataset used to render the on-screen report and generate the PDF.
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

    public List<RevenueBar> RevenueBars { get; set; } = new();
    public List<ServiceDemand> ServiceDemand { get; set; } = new();
    public List<StylistBookingReportRow> StylistBookings { get; set; } = new();
}

// A booking-level row in the downloadable stylist report.
// Payment amounts are not stored separately in the current bookings schema.
public class StylistBookingReportRow
{
    public long BookingId { get; set; }
    public string CustomerName { get; set; } = "";
    public string StylistName { get; set; } = "";
    public string ServiceName { get; set; } = "";
    public DateTime AppointmentDate { get; set; }
    public decimal Price { get; set; }
    public string PaymentMethod { get; set; } = "";
    public string Status { get; set; } = "";
    public decimal? AmountPaid { get; set; }
}
