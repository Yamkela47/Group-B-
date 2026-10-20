using System;
using System.Text.Json.Serialization;

namespace CuttingEdge.ManagerPortal.Models;

/// <summary>
/// A full day blocked by a stylist (public.blocked_dates).
/// The C# property is named Date because members cannot share the class name.
/// </summary>
public class BlockedDate
{
    public long Id { get; set; }
    public long StylistId { get; set; }

    [JsonPropertyName("blocked_date")]
    public DateTime Date { get; set; }

    public string? Reason { get; set; }
    public DateTime CreatedAt { get; set; }
}
