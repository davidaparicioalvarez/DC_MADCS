namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

pageextension 55004 "APA MADCS Prod. Order Routing" extends "Prod. Order Routing"
{
    layout
    {
        addlast(content)
        {
            field("Operation Type"; Rec."Operation Type")
            {
                ApplicationArea = All;
            }
        }
    }
}
