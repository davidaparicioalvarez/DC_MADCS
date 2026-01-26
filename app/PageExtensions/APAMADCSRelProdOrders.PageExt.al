namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

pageextension 55003 "APA MADCS Rel. Prod. Orders" extends "Released Production Orders"
{
    layout
    {
        addlast(content)
        {
            group("MADCS Production Orders Info")
            {
                Caption = 'MADCS Production Orders Info', Comment = 'ESP="Información de las órdenes de producción MADCS"';

                field("APA MADCS Can be finished"; Rec."APA MADCS Can be finished")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }
}
