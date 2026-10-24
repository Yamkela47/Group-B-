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

/// <summary>
/// An in-app notification for a profile (public.notifications).
/// </summary>

public class Notification
{
    // Primary key.
    public long NotificationId { get; set; }
    public Guid ProfileId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string? NotificationType { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }


    // Navigation property populated by the service layer.
    public Profile? Profile { get; set; }
}
