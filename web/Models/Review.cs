// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================
namespace CuttingEdge.ManagerPortal.Models;

// A customer review for a completed booking (public.reviews).
// Tracks ratings and follow-up workflow state.

public class Review
{
    public Guid ReviewId { get; set; }
    public long BookingId { get; set; }
    public Guid CustomerId { get; set; }
    public long StylistId { get; set; }
    public int Rating { get; set; }
    public int? ServiceRating { get; set; }
    public string? Comment { get; set; }
    public bool FollowUpRequired { get; set; }
    public bool Resolved { get; set; }
    public DateTime CreatedAt { get; set; }

    // Navigation properties populated by the service layer.
    public Booking? Booking { get; set; }
    public Profile? Customer { get; set; }
    public Stylist? Stylist { get; set; }
}
