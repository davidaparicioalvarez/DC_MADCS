namespace MADCS.MADCS;

/// <summary>
/// APA MADCS Log Action
/// Enum for log action types in the MADCS user log.
/// </summary>
enum 55000 "APA MADCS Log Action"
{
    Extensible = true;
    Caption = 'MADCS Log Action', Comment = 'ESP="Acción de registro MADCS"';

    /// <summary>
    /// (empty)
    /// Represents no action or an uninitialized value.
    /// </summary>
    value(0; "")
    {
        Caption = '', Locked = true;
    }

    /// <summary>
    /// OpenProductionOrder
    /// Indicates that the user is viewing a production order.
    /// </summary>
    value(1; OpenProductionOrder)
    {
        Caption = 'Open Production Order Card', Comment = 'ESP="Abrir Ficha Orden de Producción"';
    }

    /// <summary>
    /// CloseProductionOrder
    /// Indicates that the user is closing a production order card.
    /// </summary>
    value(2; CloseProductionOrder)
    {
        Caption = 'Close Production Order Card', Comment = 'ESP="Cerrar Ficha Orden de Producción"';
    }

    /// <summary>
    /// PostComponent
    /// Indicates a posting action (e.g., consumption or output posting).
    /// </summary>
    value(3; PostComponent)
    {
        Caption = 'Post Component', Comment = 'ESP="Registrar Componente"';
    }

    /// <summary>
    /// PostOutput
    /// Indicates a posting action (e.g., consumption or output posting).
    /// </summary>
    value(4; PostOutput)
    {
        Caption = 'Post Output', Comment = 'ESP="Registrar Salida"';
    }

    /// <summary>
    /// PostTime
    /// Indicates a posting action related to time registration.
    /// </summary>
    value(5; PostTime)
    {
        Caption = 'Post Time', Comment = 'ESP="Registrar Tiempo"';
    }

}
