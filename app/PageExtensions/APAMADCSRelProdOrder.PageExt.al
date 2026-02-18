namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// Page extension for Released Production Order card to display MADCS workflow status.
/// Adds a dedicated group showing completion status of consumption, output, and time tracking activities.
/// Provides quick visibility of MADCS process stages directly on the production order card.
/// </summary>
pageextension 55002 "APA MADCS Rel. Prod. Order" extends "Released Production Order"
{
    layout
    {
        addlast(content)
        {
            group("MADCS Production Order Info")
            {
                Caption = 'MADCS Production Order Info', Comment = 'ESP="Información de la orden de producción MADCS"';

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
}
