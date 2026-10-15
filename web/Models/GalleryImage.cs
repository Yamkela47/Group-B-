namespace CuttingEdge.ManagerPortal.Models;

public class GalleryImage
{
    public Guid ImageId { get; set; }
    public Guid UploadedBy { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }

    public Profile? Uploader { get; set; }
}
