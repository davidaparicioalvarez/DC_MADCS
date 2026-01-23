namespace MADCS.MADCS;

/// <summary>
/// APA MADCS Journal Type
/// Enum for journal types in the MADCS user log.
/// </summary>
enum 55001 "APA MADCS Journal Type"
{
    Extensible = true;
    Caption = 'MADCS Journal Type', Comment = 'ESP="Tipo de diario MADCS"';

    /// <summary>
    /// (empty)
    /// Represents no journal type or an uninitialized value.
    /// </summary>
    value(0; "")
    {
        Caption = '', Locked = true;
    }

    /// <summary>
    /// Preparation
    /// Represents a Preparation journal type.
    /// </summary>
    value(1; Preparation)
    {
        Caption = 'Preparation', Comment = 'ESP="Preparación"';
    }

    /// <summary>
    /// Execution
    /// Represents an Execution journal type.
    /// </summary>
    value(2; Execution)
    {
        Caption = 'Execution', Comment = 'ESP="Ejecución"';
    }

    /// <summary>
    /// Clean
    /// Represents a Clean journal type.
    /// </summary>
    value(3; Clean)
    {
        Caption = 'Clean', Comment = 'ESP="Limpieza"';
    }

    /// <summary>
    /// Fault
    /// Represents a fault journal type.
    /// </summary>
    value(4; Fault)
    {
        Caption = 'Fault', Comment = 'ESP="Avería"';
    }

    /// <summary>
    /// "Execution with Fault"
    /// Represents a fault journal type.
    /// </summary>
    value(5; "Execution with Fault")
    {
        Caption = 'Execution with Fault', Comment = 'ESP="Ejecución con Avería"';
    }
}
