namespace MADCS.MADCS;

/// <summary>
/// APA MADCS Operator Actions
/// Enum for operator actions in the MADCS system.
/// </summary>
enum 55003 "APA MADCS Operator Actions"
{
    Extensible = true;
    
    value(0; "")
    {
        Caption = '', Locked = true;
    }
    value(1; Preparation)
    {
        Caption = 'Preparation', Comment = 'ESP="Preparación"';
    }
    value(2; Execution)
    {
        Caption = 'Execution', Comment = 'ESP="Ejecución"';
    }
    value(3; Cleaning)
    {
        Caption = 'Cleaning', Comment = 'ESP="Limpieza"';
    }
    value(4; Stops)
    {
        Caption = 'Stops', Comment = 'ESP="Paros"';
    }
}
