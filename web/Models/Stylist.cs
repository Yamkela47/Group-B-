
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
// A stylist record (public.stylists), linking a Profile to stylist-specific data

public class Stylist
{
    public long StylistId { get; set; }
    public Guid ProfileId { get; set; }
    public string? PhotoUrl { get; set; }
    public bool Active { get; set; } = true;
    public DateTime CreatedAt { get; set; }


    // Navigation property populated by the service layer.
    public Profile? Profile { get; set; }
}
