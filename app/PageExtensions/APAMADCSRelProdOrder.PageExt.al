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

                field("APA MADCS Can be finished"; Rec."APA MADCS Can be finished")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }
}
