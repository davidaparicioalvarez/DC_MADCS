namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Pro. Order Line Time
/// Table to log time entries for production order lines in the MADCS system.
/// </summary>
table 55001 "APA MADCS Pro. Order Line Time"
{
    Caption = 'Production Order Line Time', Comment = 'ESP="Tiempo Línea Orden de Producción"';
    LookupPageId = "APA MADCS Time Part";
    DrillDownPageId = "APA MADCS Time Part";
    DataClassification = SystemMetadata;
    
    fields
    {
        field(1; Status; Enum "Production Order Status")
        {
            Caption = 'Status', Comment = 'ESP="Estado"';
            ToolTip = 'Specifies the status of the production order line.', Comment = 'ESP="Especifica el estado de la línea de orden de producción."';
        }
        field(2; "Prod. Order No."; Code[20])
        {
            Caption = 'Prod. Order No.', Comment = 'ESP="Nº Orden de Producción"';
            ToolTip = 'Specifies the production order number.', Comment = 'ESP="Especifica el número de orden de producción."';
        }
        field(3; "Prod. Order Line No."; Integer)
        {
            Caption = 'Prod. Order Line No.', Comment = 'ESP="Nº Línea Orden de Producción"';
            ToolTip = 'Specifies the line number of the production order.', Comment = 'ESP="Especifica el número de línea de la orden de producción."';
        }
        field(4; "Line No."; Integer)
        {
            Caption = 'Line No.', Comment = 'ESP="Nº Línea"';
            ToolTip = 'Specifies the line number.', Comment = 'ESP="Especifica el número de línea."';
        }
        field(5; "Operator Code"; Code[20])
        {
            Caption = 'Operator Code', Comment = 'ESP="Código de Operario"';
            ToolTip = 'Specifies the operator code.', Comment = 'ESP="Especifica el código de operario."';
        }
        field(6; "Action"; Enum "APA MADCS Journal Type")
        {
            Caption = 'Action', Comment = 'ESP="Acción"';
            ToolTip = 'Specifies the action type.', Comment = 'ESP="Especifica el tipo de acción."';
        }
        field(7; "End"; Boolean)
        {
            Caption = 'End', Comment = 'ESP="Fin"';
            ToolTip = 'Indicates if the time entry marks the end of an operation.', Comment = 'ESP="Indica si la entrada de tiempo marca el fin de una operación."';
        }
        field(8; "Date Time"; DateTime)
        {
            Caption = 'Date Time', Comment = 'ESP="Fecha y Hora"';
            ToolTip = 'Specifies the date and time of the time entry.', Comment = 'ESP="Especifica la fecha y hora de la entrada de tiempo."';
        }
        field(9; "BreakDown Code"; Code[20])
        {
            Caption = 'BreakDown Code', Comment = 'ESP="Código de Paro"';
            ToolTip = 'Specifies the code of the breakdown.', Comment = 'ESP="Especifica el código de paro."';
            TableRelation = "DC Detalles de paro".Code;
        }
    }
    keys
    {
        key(PK; Status,"Prod. Order No.","Prod. Order Line No.","Line No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Prod. Order No.","Prod. Order Line No.","Line No.","Operator Code","Action","End","Date Time","BreakDown Code")
        {
        }
        fieldgroup(Brick; Status,"Prod. Order No.","Prod. Order Line No.","Line No.","Operator Code","Action","End","Date Time","BreakDown Code")
        {
        }
    }
}
