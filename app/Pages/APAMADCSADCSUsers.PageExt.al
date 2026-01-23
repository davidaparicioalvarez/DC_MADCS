namespace MADCS.MADCS;

using Microsoft.Warehouse.ADCS;

pageextension 55001 "APA MADCS ADCS Users" extends "ADCS Users"
{
    layout
    {
        addafter(Password)
        {
            field(MADCSPassword; Rec."MADCS Password")
            {
                ApplicationArea = All;
                ExtendedDatatype = Masked;
            }
        }
    }
}
