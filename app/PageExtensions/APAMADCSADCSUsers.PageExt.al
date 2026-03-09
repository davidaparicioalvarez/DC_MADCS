namespace MADCS.MADCS;

using Microsoft.Warehouse.ADCS;

pageextension 55001 "APA MADCS ADCS Users" extends "ADCS Users"
{
    layout
    {
        addafter(Password)
        {
            field(MADCSPassword; Rec."APA MADCS Password")
            {
                ApplicationArea = All;
                ExtendedDatatype = Masked;
            }
            field("APA MADCS Machine Center"; Rec."APA MADCS Machine Center")
            {
                ApplicationArea = All;
            }
        }
    }
}
