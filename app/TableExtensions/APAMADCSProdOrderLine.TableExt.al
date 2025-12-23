namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Prod. Order Line Extension
/// TableExtension to add a field indicating if a user is working with the Prod. Order Line.
/// </summary>
tableextension 55000 "APA MADCS Prod. Order Line" extends "Prod. Order Line"
{
    fields
    {
        field(55000; "APA MADCS User Working"; Code[50])
        {
            Caption = 'User Working', Comment = 'ESP="Usuario trabajando"';
            ToolTip = 'Specifies the user currently working with this production order line.', Comment = 'ESP="Especifica el usuario que está trabajando con esta línea de orden de producción."';
            DataClassification = SystemMetadata;
        }
    }
}
