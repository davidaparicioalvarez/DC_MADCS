namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

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
