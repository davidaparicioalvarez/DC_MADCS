namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// Page extension for Released Production Orders list to display MADCS workflow completion status.
/// Adds visibility of consumption, output, and time tracking completion flags for MADCS process monitoring.
/// </summary>
pageextension 55003 "APA MADCS Rel. Prod. Orders" extends "Released Production Orders"
{
    layout
    {
        addlast(Control1)
        {
            field("APA MADCS Consumption finished"; Rec."APA MADCS Consumption finished")
            {
                ApplicationArea = All;
            }
            field("APA MADCS Output finished"; Rec."APA MADCS Output finished")
            {
                ApplicationArea = All;
            }
            field("APA MADCS Time finished"; Rec."APA MADCS Time finished")
            {
                ApplicationArea = All;
            }
        }
    }
}
