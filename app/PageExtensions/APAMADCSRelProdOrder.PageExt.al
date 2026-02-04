namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

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
