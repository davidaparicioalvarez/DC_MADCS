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
            CalcFormula = min("Prod. Order Component"."APA MADCS Verified" where(Status = field(Status),
                                                                              "Prod. Order No." = field("Prod. Order No."),
                                                                              "Prod. Order Line No." = field("Line No.")));
        }

        field(55001; "APA MADCS User Working"; Code[50])
        {
            Caption = 'User Working', Comment = 'ESP="Usuario trabajando"';
            ToolTip = 'Specifies the user currently working with this production order line.', Comment = 'ESP="Especifica el usuario que está trabajando con esta línea de orden de producción."';
            DataClassification = SystemMetadata;
        }

        field(55002; "APA MADCS Output finished"; Boolean)
        {
            Caption = 'Output finished', Comment = 'ESP="Salida finalizada"';
            ToolTip = 'Indicates whether the production order line can be finished based on MADCS verification.', Comment = 'ESP="Indica si la línea de orden de producción puede ser finalizada en función de la verificación de MADCS."';
            Editable = false;
            AllowInCustomizations = Never;
            FieldClass = FlowField;
            CalcFormula = min("Production Order"."APA MADCS Output finished" where(Status = field(Status),
                                                                                   "No." = field("Prod. Order No.")));
        }

        field(55003; "APA MADCS Consumption finished"; Boolean)
        {
            Caption = 'Consumption finished', Comment = 'ESP="Consumo finalizado"';
            ToolTip = 'Indicates whether the production order line can be finished based on MADCS verification.', Comment = 'ESP="Indica si la línea de orden de producción puede ser finalizada en función de la verificación de MADCS."';
            Editable = false;
            AllowInCustomizations = Never;
            FieldClass = FlowField;
            CalcFormula = min("Production Order"."APA MADCS Consumption finished" where(Status = field(Status),
                                                                                   "No." = field("Prod. Order No.")));
        }

        field(55004; "APA MADCS Time finished"; Boolean)
        {
            Caption = 'Time finished', Comment = 'ESP="Tiempo finalizado"';
            ToolTip = 'Indicates whether the production order line can be finished based on MADCS verification.', Comment = 'ESP="Indica si la línea de orden de producción puede ser finalizada en función de la verificación de MADCS."';
            Editable = false;
            AllowInCustomizations = Never;
            FieldClass = FlowField;
            CalcFormula = min("Production Order"."APA MADCS Time finished" where(Status = field(Status),
                                                                                   "No." = field("Prod. Order No.")));
        }

        field(55005; "APA MADCS Picking Status"; Enum "APA MADCS Picking Status")
        { // Derived from DC extension
            Caption = 'Picking Status', Comment = 'ESP="APA MADCS Picking Status"';
            Editable = false;
            AllowInCustomizations = Never;
            FieldClass = FlowField;
            CalcFormula = min("Production Order"."APA MADCS Picking Status" where(Status = field(Status),
                                                                                   "No." = field("Prod. Order No.")));
        }
    }
}
