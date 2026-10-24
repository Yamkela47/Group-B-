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

/// <summary>
/// One actual calendar date, assembled from stylist_schedules and blocked_dates.
/// This is display only; it never modifies the stylist's recurring availability.
/// </summary>
public sealed class StylistAvailabilityDayViewModel
{
    public DateTime Date { get; set; }
    public bool HasShift { get; set; }
    public bool IsAvailable { get; set; }
    public bool IsBlocked { get; set; }
    public string? Reason { get; set; }
    public string? Hours { get; set; }
}

/// <summary>
/// All-time rating summary based on review.rating; service ratings are separate.
/// </summary>
public sealed class StylistRatingSummaryViewModel
{
    public int TotalReviews { get; set; }
    public double AverageStylistRating { get; set; }
    public int LowRatingCount { get; set; }
    public int ServiceRatingCount { get; set; }
    public double? AverageServiceRating { get; set; }
    public int[] StarCounts { get; set; } = new int[6];


    // Safe accessor: returns 0 for out-of-range star values so the view never throws.
    public int CountForStars(int stars) => stars >= 1 && stars <= 5
        ? StarCounts[stars] : 0;
}
