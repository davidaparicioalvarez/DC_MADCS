namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;
using Microsoft.Warehouse.Activity.History;

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

    actions
    {
        addafter("Put-away/Pick Lines/Movement Lines")
        {
            action("Reg. Put-away/Reg. Pick Lines/Reg. Movement Lines")
            {
                ApplicationArea = Warehouse;
                Caption = 'Reg. Put-away/Reg. Pick Lines/Reg. Movement Lines', Comment = 'ESP="Líneas de registro de ubicaciones/recogidas/movimientos"';
                Image = PutawayLines;
                RunObject = page "Registered Whse. Act.-Lines";
                RunPageLink = "Source Type" = filter(5406 | 5407),
                                "Source Subtype" = const("3"),
                                "Source No." = field("No.");
                RunPageView = sorting("Source Type", "Source Subtype", "Source No.", "Source Line No.", "Source Subline No.", "Action Type");
                ToolTip = 'View the list of ongoing inventory put-aways, picks, or movements for the order.', Comment = 'ESP="Ver la lista de ubicaciones/recogidas/movimientos de inventario en curso para la orden."';
            }
        }
    }
}
