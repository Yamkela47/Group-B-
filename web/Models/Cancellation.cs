// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================
using System;

namespace CuttingEdge.ManagerPortal.Models;

// Records who cancelled a booking and why (public.cancellations).
// Includes a computed display string for the cancellation author.

public class Cancellation
{
    public long CancellationId { get; set; }

    public long BookingId { get; set; }

    public string? Reason { get; set; }

    // UUID of the person who cancelled.
    public string? CancelledBy { get; set; }

    // Manager, Customer, Stylist or System.
    public string? CancelledActor { get; set; }

    // Name of the person who cancelled.
    public string? CancelledByName { get; set; }

    public DateTime CancelledAt { get; set; }


    // Computed, human-readable label for the canceller.
    // Excluded from JSON so it isn't serialized back to clients.
    [System.Text.Json.Serialization.JsonIgnore]
    public string CancelledByDisplay
    {
        get
        {
            var actor = CancelledActor?.Trim();
            var name = CancelledByName?.Trim();

            if (string.IsNullOrWhiteSpace(actor))
            {
                return string.IsNullOrWhiteSpace(name)
                    ? "Not recorded"
                    : name;
            }

            // No name, or name duplicates the actor: show just the actor
            return string.IsNullOrWhiteSpace(name) ||
                   string.Equals(
                       name,
                       actor,
                       StringComparison.OrdinalIgnoreCase)
                ? actor
                : $"{name} ({actor})";
        }
    }

    // Back-reference to the owning booking (populated by the service)
    public Booking? Booking { get; set; }
}
