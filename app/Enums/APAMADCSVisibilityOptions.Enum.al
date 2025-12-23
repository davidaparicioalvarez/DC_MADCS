namespace MADCS.MADCS;

/// <summary>
/// APA MADCS Visibility Options
/// Enum for different visibility options in the MADCS main card.
/// </summary>
enum 55002 "APA MADCS Visibility Options"
{
    Extensible = true;
    
    value(0; "")
    {
        Caption = '', Locked = true;
    }
    value(1; Verifications)
    {
        Caption = 'Verifications', Comment = 'ESP="Verificaciones"';
    }
    value(2; "Time")
    {
        Caption = 'Time', Comment = 'ESP="Tiempo"';
    }
    value(3; Stops)
    {
        Caption = 'Stops', Comment = 'ESP="Paradas"';
    }
    value(4; "Quality Measures")
    {
        Caption = 'Quality Measures', Comment = 'ESP="Medidas de Calidad"';
    }
    value(5; Consumptions)
    {
        Caption = 'Consumptions', Comment = 'ESP="Consumos"';
    }
    value(6; Outputs)
    {
        Caption = 'Outputs', Comment = 'ESP="Salidas"';
    }
}
