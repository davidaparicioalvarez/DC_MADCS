namespace MADCS.MADCS;

/// <summary>
/// APA MADCS User Log
/// Table to log all user posts, changes, and actions in the manufacturing data capture process.
/// </summary>
table 55000 "APA MADCS User Log"
{
    Caption = 'MADCS User Log', Comment = 'ESP="Registro de usuario MADCS"';
    Extensible = true;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.', Comment = 'ESP="Nº de entrada"';
            AutoIncrement = true;
        }
        field(2; "User ID"; Code[50])
        {
            Caption = 'User ID', Comment = 'ESP="ID de usuario"';
        }
        field(3; "Action DateTime"; DateTime)
        {
            Caption = 'Action DateTime', Comment = 'ESP="Fecha y hora de acción"';
        }
        field(4; "Production Order No."; Code[20])
        {
            Caption = 'Production Order No.', Comment = 'ESP="Nº orden de producción"';
        }
        field(5; "Component/Output No."; Code[20])
        {
            Caption = 'Component/Output No.', Comment = 'ESP="Nº componente/salida"';
        }
        field(6; "Log Action"; Enum "APA MADCS Log Action")
        {
            Caption = 'Log Action', Comment = 'ESP="Acción de registro"';
        }
        field(7; "Old Value"; Text[100])
        {
            Caption = 'Old Value', Comment = 'ESP="Valor anterior"';
        }
        field(8; "New Value"; Text[100])
        {
            Caption = 'New Value', Comment = 'ESP="Valor nuevo"';
        }
        field(9; "Journal Type"; Enum "APA MADCS Journal Type")
        {
            Caption = 'Journal Type', Comment = 'ESP="Tipo de diario"';
        }
        field(10; "Journal Line No."; Integer)
        {
            Caption = 'Journal Line No.', Comment = 'ESP="Nº línea de diario"';
        }
        field(11; "Comment"; Text[250])
        {
            Caption = 'Comment', Comment = 'ESP="Comentario"';
        }
        field(12; "Log Type"; Enum "APA MADCS Log Type")
        {
            Caption = 'Log Type', Comment = 'ESP="Tipo de log"';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Entry No.", "User ID", "Action DateTime", "Production Order No.", "Log Action")
        {
        }
        fieldgroup(Brick; "Entry No.", "User ID")
        {
        }
    }
}
