namespace CuttingEdge.ManagerPortal.Models;

public class Notification
{
    public Guid NotificationId { get; set; }
    public Guid ProfileId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string? NotificationType { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }

    public Profile? Profile { get; set; }
}
