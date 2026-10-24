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
using System.Text.Json.Serialization;

namespace CuttingEdge.ManagerPortal.Models;

/// <summary>
/// A full day blocked by a stylist (public.blocked_dates).
/// The C# property is named Date because members cannot share the class name.
/// </summary>
public class BlockedDate
{
    // Primary key of the blocked_dates row.
    public long Id { get; set; }
    // Stylist whose calendar is blocked for the whole day.
    public long StylistId { get; set; }


    // Maps to the DB column "blocked_date"; renamed in C# to avoid clashing with the class name.
    [JsonPropertyName("blocked_date")]
    public DateTime Date { get; set; }


    // Optional free-text reason shown to managers.
    public string? Reason { get; set; }
    public DateTime CreatedAt { get; set; }
}
