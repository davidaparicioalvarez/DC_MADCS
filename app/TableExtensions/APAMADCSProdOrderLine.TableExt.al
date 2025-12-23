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
        field(55000; "APA MADCS Verified"; Boolean)
        {
            Caption = 'MADCS Verified', Comment = 'ESP="MADCS verificado"';
            ToolTip = 'Indicates whether the production order line has been verified in MADCS.', Comment = 'ESP="Indica si la línea de orden de producción ha sido verificada en MADCS."';
            Editable = false;
            AllowInCustomizations = Never;
            FieldClass = FlowField;
            CalcFormula = min("Prod. Order Component"."MADCS Verified" where (Status = field(Status),
                                                                              "Prod. Order No." = field("Prod. Order No."), 
                                                                              "Prod. Order Line No." = field("Line No.")));
        }

        field(55001; "APA MADCS User Working"; Code[50])
        {
            Caption = 'User Working', Comment = 'ESP="Usuario trabajando"';
            ToolTip = 'Specifies the user currently working with this production order line.', Comment = 'ESP="Especifica el usuario que está trabajando con esta línea de orden de producción."';
            DataClassification = SystemMetadata;
        }
    }
}
