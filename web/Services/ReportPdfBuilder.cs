// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

using System.Globalization;
using System.Text;
using CuttingEdge.ManagerPortal.ViewModels;

namespace CuttingEdge.ManagerPortal.Services;

/// <summary>
/// Dependency-free, multi-page A4-landscape PDF report. Uses the built-in
/// PDF Helvetica fonts and draws repeating table headers on page breaks.
/// </summary>
internal sealed class ReportPdfBuilder
{
    // Page geometry in PDF points (1 pt = 1/72 inch). 842x595 = A4 landscape.
    private const double PageWidth = 842;
    private const double PageHeight = 595;
    private const double Left = 43;
    private const double Right = 799;
    private const double Bottom = 65;
    private readonly List<StringBuilder> _pages = new();
    private StringBuilder _canvas = new();
    private double _y;
    private string _repeatSection = "";
    private int _rowNumber;

    // One StringBuilder per page. _canvas points to the page currently being drawn.
    private static string N(double value) => value.ToString("0.##", CultureInfo.InvariantCulture);
    private static string Money(decimal amount) => "R " + amount.ToString("N2", CultureInfo.InvariantCulture);


    // Formats numbers with a dot decimal separator regardless of server locale.
    private ReportPdfBuilder() => NewPage();
    public static byte[] Build(ReportData report)
    {
        var pdf = new ReportPdfBuilder();
        pdf.WriteReport(report);
        return pdf.Save();
    }

    private void NewPage() //Starts a new page, draws the header band, and resets the cursor.
    {
        _canvas = new StringBuilder();
        _pages.Add(_canvas);
        _y = 44;
        _rowNumber = 0;
        Fill(Left, 24, 756, 4, "0.82 0.62 0.13");
        Text(Left, 39, "CUTTING EDGE  /  SALON MANAGEMENT", 11, true, "0.12 0.12 0.12");
        Text(Left, 55, "STYLIST BOOKING & PAYMENT REPORT", 8, false, "0.40 0.40 0.40");
        _y = 73;
    }


    // Makes sure at least <paramref name="needed"/> points fit on the page;
    //otherwise starts a new page and repeats the section header + table header
    private void Ensure(double needed)
    {
        if (_y + needed <= PageHeight - Bottom) return;
        NewPage();
        if (_repeatSection.Length > 0)
        {
            Text(Left, _y + 10, _repeatSection + "  (continued)", 11, true);
            _y += 22;
            TableHeader();
        }
    }

    // Sanitises text for the built-in PDF Helvetica font, which only supports
    // WinAnsi characters. Replaces smart quotes/em-dashes, strips combining marks
    // (decomposed accents), and substitutes unknown characters with '?'
    private static string Safe(string? input)
    {
        // The built-in Helvetica font is restricted to WinAnsi characters.
        var normal = (input ?? "").Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (var c in normal)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark) continue;
            if (c == '\n' || c == '\r' || c == '\t') sb.Append(' ');
            else if (c is '–' or '—' or '−') sb.Append('-');
            else if (c is '’' or '‘') sb.Append((char)39);
            else if (c is '“' or '”') sb.Append('"');
            else if (c >= ' ' && c <= '~') sb.Append(c);
            else if (c >= 160 && c <= 255) sb.Append(c);
            else sb.Append('?');
        }
        return sb.ToString();
    }

    //Escapes special characters required inside a PDF literal string
    private static string Escape(string s) => Safe(s).Replace("\\", "\\\\").Replace("(", "\\(").Replace(")", "\\)");


    //Truncates text with an ellipsis so it fits within the given column width,
    //based on an approximate per-character width for the given font size.
    private static string Fit(string? input, double width, double fontSize = 8)
    {
        var s = Safe(input).Trim();
        var maxChars = Math.Max(2, (int)((width - 11) / (fontSize * 0.54)));
        return s.Length <= maxChars ? s : s[..Math.Max(1, maxChars - 3)] + "...";
    }

    //Draws a single line of text at (x, y) with optional bold/colour
    private void Text(double x, double y, string value, double size = 9, bool bold = false, string color = "0.18 0.18 0.18")
    {
        _canvas.Append(color).Append(" rg BT /").Append(bold ? "F2" : "F1").Append(' ')
            .Append(N(size)).Append(" Tf 1 0 0 1 ").Append(N(x)).Append(' ')
            .Append(N(PageHeight - y)).Append(" Tm (").Append(Escape(value)).Append(") Tj ET\n");
    }

    private void Fill(double x, double y, double w, double h, string color)
    {
        _canvas.Append(color).Append(" rg ").Append(N(x)).Append(' ')
            .Append(N(PageHeight - y - h)).Append(' ').Append(N(w)).Append(' ')
            .Append(N(h)).Append(" re f\n");
    }

    private void Rule(double y)
    {
        _canvas.Append("0.86 0.86 0.86 RG 0.5 w ").Append(N(Left)).Append(' ')
            .Append(N(PageHeight - y)).Append(" m ").Append(N(Right)).Append(' ')
            .Append(N(PageHeight - y)).Append(" l S\n");
    }

    private void Line(string label, string value)
    {
        Text(Left + 12, _y, label, 9, true);
        Text(Left + 195, _y, value, 9);
        _y += 19;
    }

    //Renders the report title, summary box, per-stylist tables, and footnotes
    private void WriteReport(ReportData report)
    {
        Text(Left, _y + 10, "Reporting period: " + report.PeriodLabel, 12, true);
        _y += 34;
        Fill(Left, _y - 14, 756, 114, "0.96 0.96 0.96");
        Line("Completed bookings", report.CompletedBookings.ToString(CultureInfo.InvariantCulture));
        Line("Cancelled bookings", report.Cancelled.ToString(CultureInfo.InvariantCulture));
        Line("Cash revenue (estimated)", Money(report.CashRevenue));
        Line("Card revenue (estimated)", Money(report.CardRevenue));
        Line("Total revenue (estimated)", Money(report.TotalRevenue));
        _y += 17;

        Text(Left, _y + 9, "CUSTOMERS BOOKED WITH EACH STYLIST", 13, true);
        _y += 31;
        var rows = report.StylistBookings;
        if (rows.Count == 0)
        {
            Text(Left + 8, _y + 9, "No bookings found for the selected period.", 10);
            _y += 34;
        }
        else
        {
            foreach (var group in rows.GroupBy(r => r.StylistName)
                .OrderBy(g => g.Key, StringComparer.OrdinalIgnoreCase))
            {
                // Start each new stylist section with a fresh header, even
                // if the prior section ended near the bottom of a page.
                _repeatSection = "";
                Ensure(73);
                _repeatSection = "Stylist: " + group.Key;
                Text(Left, _y + 10, Fit(_repeatSection, 655, 11), 11, true);
                Text(Left + 655, _y + 10, $"{group.Count()} booking(s)", 9);
                _y += 22;
                TableHeader();
                foreach (var row in group.OrderBy(x => x.AppointmentDate).ThenBy(x => x.BookingId))
                {
                    Ensure(27);
                    TableRow(row);
                }
                _repeatSection = "";
                _y += 13;
            }
        }
        Ensure(54);
        Rule(_y + 3);
        _y += 21;
        Text(Left, _y,
            "* Amount paid is estimated as the service price for completed bookings; it is not a verified payment transaction.",
            8, false, "0.35 0.35 0.35");
        _y += 15;
        Text(Left, _y,
            "For other statuses, the paid amount is unknown (-). Prices reflect current service pricing, not historical receipts.",
            8, false, "0.35 0.35 0.35");
    }

    private static readonly double[] Widths = { 144, 145, 85, 78, 101, 103, 100 };
    private static readonly string[] Headers = { "Customer", "Service", "Date", "Price", "Payment method", "Amount paid*", "Status" };

    private void TableHeader() //Draws the dark table-header band.
    {
        Fill(Left, _y, 756, 25, "0.16 0.16 0.16");
        var x = Left;
        for (var i = 0; i < Headers.Length; i++)
        {
            Text(x + 5, _y + 17, Headers[i], 8, true, "1 1 1");
            x += Widths[i];
        }
        _y += 25;
        _rowNumber = 0;
    }

    //Draws one booking row with zebra striping and a bottom rule
    private void TableRow(StylistBookingReportRow row)
    {
        if (_rowNumber++ % 2 == 0) Fill(Left, _y, 756, 26, "0.96 0.96 0.96");
        var values = new[]
        {
            row.CustomerName, row.ServiceName,
            row.AppointmentDate.ToString("dd MMM yyyy", CultureInfo.InvariantCulture),
            Money(row.Price), row.PaymentMethod,
            row.AmountPaid.HasValue ? Money(row.AmountPaid.Value) : "-",
            row.Status
        };
        var x = Left;
        for (var i = 0; i < values.Length; i++)
        {
            Text(x + 5, _y + 17, Fit(values[i], Widths[i], 8), 8);
            x += Widths[i];
        }
        _y += 26;
        Rule(_y);
    }

    // Serialises all pages into a valid PDF 1.4 file, writing the trailer,
    // cross-reference table, and per-page footer labels ("Page X / Y").
    private byte[] Save()
    {
        // Stamp page numbers and footer text on each page before serialising.
        for (var i = 0; i < _pages.Count; i++)
        {
            var page = i + 1;
            var oldCanvas = _canvas;
            _canvas = _pages[i];
            Rule(PageHeight - 38);
            Text(Left, PageHeight - 23, "Cutting Edge / Confidential manager report", 8, false, "0.45 0.45 0.45");
            Text(Right - 75, PageHeight - 23, $"Page {page} / {_pages.Count}", 8, false, "0.45 0.45 0.45");
            _canvas = oldCanvas;
        }

        var objects = new List<byte[]>();
        var kids = string.Join(" ", Enumerable.Range(0, _pages.Count).Select(i => $"{5 + i * 2} 0 R"));
        objects.Add(Bytes("<< /Type /Catalog /Pages 2 0 R >>"));
        objects.Add(Bytes($"<< /Type /Pages /Kids [{kids}] /Count {_pages.Count} >>"));
        objects.Add(Bytes("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"));
        objects.Add(Bytes("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>"));

        foreach (var page in _pages) // Emit each page object followed by its content stream object.
        {
            var stream = Bytes(page.ToString());
            var pageId = objects.Count + 1;
            objects.Add(Bytes($"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PageWidth} {PageHeight}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents {pageId + 1} 0 R >>"));
            using var content = new MemoryStream();
            Write(content, $"<< /Length {stream.Length} >>\nstream\n");
            content.Write(stream);
            Write(content, "\nendstream");
            objects.Add(content.ToArray());
        }

        using var output = new MemoryStream();
        Write(output, "%PDF-1.4\n");
        var offsets = new List<long>();
        for (var i = 0; i < objects.Count; i++)
        {
            offsets.Add(output.Position); // Save byte offset for the xref table.
            Write(output, $"{i + 1} 0 obj\n");
            output.Write(objects[i]);
            Write(output, "\nendobj\n");
        }

        // Cross-reference table + trailer pointing back to the catalog.
        var xref = output.Position;
        Write(output, $"xref\n0 {objects.Count + 1}\n0000000000 65535 f \n");
        foreach (var offset in offsets)
            Write(output, $"{offset:D10} 00000 n \n");
        Write(output, $"trailer\n<< /Size {objects.Count + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF");
        return output.ToArray();
    }

    // Latin1 is the correct encoding for PDF WinAnsi content when using the built-in fonts.
    private static byte[] Bytes(string s) => Encoding.Latin1.GetBytes(s);
    private static void Write(Stream stream, string s) => stream.Write(Bytes(s));
}
