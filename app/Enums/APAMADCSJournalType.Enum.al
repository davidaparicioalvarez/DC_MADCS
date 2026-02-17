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
    value(10; Preparation)
    {
        Caption = 'Preparation', Comment = 'ESP="Preparación"';
    }

    /// <summary>
    /// Execution
    /// Represents an Execution journal type.
    /// </summary>
    value(20; Execution)
    {
        Caption = 'EXECUTION without fault', Comment = 'ESP="EJECUCION sin avería"';
    }

    /// <summary>
    /// "Execution with Fault"
    /// Represents a fault journal type.
    /// </summary>
    value(21; "Execution with Fault")
    {
        Caption = 'Execution WITH FAULT', Comment = 'ESP="Ejecución CON AVERÍA"';
    }

    /// <summary>
    /// Clean
    /// Represents a Clean journal type.
    /// </summary>
    value(30; Cleaning)
    {
        Caption = 'Cleaning', Comment = 'ESP="Limpieza"';
    }

    /// <summary>
    /// Fault
    /// Represents a fault journal type.
    /// </summary>
    value(99; Fault)
    {
        Caption = 'Blocking Fault', Comment = 'ESP="Avería bloqueante"';
    }

}
