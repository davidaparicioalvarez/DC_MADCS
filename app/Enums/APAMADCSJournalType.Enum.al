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
    /// Consumption
    /// Represents a consumption journal type.
    /// </summary>
    value(1; Consumption)
    {
        Caption = 'Consumption', Comment = 'ESP="Consumo"';
    }

    /// <summary>
    /// Output
    /// Represents an output journal type.
    /// </summary>
    value(2; Output)
    {
        Caption = 'Output', Comment = 'ESP="Salida"';
    }

    /// <summary>
    /// Time
    /// Represents a time journal type.
    /// </summary>
    value(3; Time)
    {
        Caption = 'Time', Comment = 'ESP="Tiempo"';
    }
}
