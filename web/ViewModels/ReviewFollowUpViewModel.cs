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
// Combines a review with its associated follow-up record for the
// review-details page (apology email + stylist report workflow).

public class ReviewFollowUpViewModel
{
    public Review Review { get; set; } = new();
    public ReviewFollowUpRecord FollowUp { get; set; } = new();
}

// Stored in public.review_followups, one row per review.
// Tracks what was sent to whom and when, for a single review's follow-up flow.
public class ReviewFollowUpRecord
{
    public Guid ReviewId { get; set; }
    public DateTimeOffset? CustomerSentAt { get; set; }
    public DateTimeOffset? CustomerNotifiedAt { get; set; }
    public DateTimeOffset? StylistSentAt { get; set; }
    public DateTimeOffset? StylistNotifiedAt { get; set; }
    public string? StylistReportTitle { get; set; }
    public string? CustomerSentTo { get; set; }
    public string? StylistSentTo { get; set; }
    public string? ApologySubject { get; set; }
    public string? ApologyMessage { get; set; }
    public string? StylistReport { get; set; }
    public string? ManagerEmail { get; set; }
}
