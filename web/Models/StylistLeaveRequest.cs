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
using System.Collections.Generic;

namespace CuttingEdge.ManagerPortal.Models;

/// <summary>A single date in a stylist's grouped leave/block-date request.</summary>
public sealed class StylistLeaveRequest
{
    public long RequestId { get; set; }
    public Guid GroupId { get; set; }
    public long StylistId { get; set; }
    public DateTime RequestedDate { get; set; }
    public string RequestType { get; set; } = "leave";
    public string Reason { get; set; } = "";
    public string Status { get; set; } = "pending";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ReviewedAt { get; set; }
    public Guid? ReviewedBy { get; set; }
    public long? EnquiryId { get; set; }
    public string StylistName { get; set; } = "";
}

/// <summary>Manager-portal view model grouping all requested dates together.</summary>
public sealed class LeaveRequestGroup
{
    public Guid GroupId { get; set; }
    public long EnquiryId { get; set; }
    public long StylistId { get; set; }
    public string StylistName { get; set; } = "";
    public string RequestType { get; set; } = "leave";
    public string Reason { get; set; } = "";
    public DateTime FirstDate { get; set; }
    public DateTime LastDate { get; set; }
    public int DayCount { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public List<StylistLeaveRequest> Items { get; set; } = new();

    public string RangeLabel => FirstDate == LastDate
        ? FirstDate.ToString("ddd dd MMM yyyy")
        : $"{FirstDate:ddd dd MMM} – {LastDate:ddd dd MMM yyyy} ({DayCount} day(s))";

    public string TypeLabel => RequestType == "leave" ? "Leave" : "Block date";
}
