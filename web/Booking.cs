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

// A customer appointment with a stylist for a specific service
// (public.bookings). Holds IDs plus optional navigation properties
// that are populated by the service layer for display.

public class Booking
{
    // Primary key.
    public long BookingId { get; set; }
    public Guid CustomerId { get; set; }
    public long StylistId { get; set; }
    public long ServiceId { get; set; }
    public long PaymentMethodId { get; set; }
    public DateTime AppointmentDate { get; set; }
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public string Status { get; set; } = "Incomplete";
    public string? AdditionalNotes { get; set; }
    public DateTime CreatedAt { get; set; }

    // Navigation properties (filled in by the service layer)
    // These are read-only conveniences for views; not guaranteed to be set.
    public Profile? Customer { get; set; }
    public Stylist? Stylist { get; set; }
    public Service? Service { get; set; }
    public PaymentMethod? PaymentMethod { get; set; }
    public Cancellation? Cancellation { get; set; }
}
