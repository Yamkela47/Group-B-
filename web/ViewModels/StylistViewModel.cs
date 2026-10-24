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
// Form model for creating and editing a stylist.

public class StylistViewModel
{
    public long StylistId { get; set; }
    public Guid ProfileId { get; set; }

    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Role { get; set; } = "Stylist";
    public string? WorkingHours { get; set; }
    public bool Active { get; set; } = true;
    public string? PhotoUrl { get; set; }

    // Optional password chosen by manager; used only for Supabase Auth creation.
    // Leaving it blank sends the normal invite to create a password.
    [System.ComponentModel.DataAnnotations.DataType(System.ComponentModel.DataAnnotations.DataType.Password)]
    [System.ComponentModel.DataAnnotations.MinLength(8)]
    public string? InitialPassword { get; set; }

    /// <summary>Checked services (checkbox name="ServiceIds").</summary>
    public List<long> ServiceIds { get; set; } = new();
}
