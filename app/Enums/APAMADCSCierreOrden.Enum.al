namespace MADCS.MADCS;

/// <summary>
/// Enum APA MADCS Cierre Orden (ID 55008).
/// </summary>
enum 55008 "APA MADCS Cierre Orden"
{
    Extensible = true;

    value(0; Correcto)
    {
        Caption = 'Ok', Comment = 'ESP="Correcto"';
    }
    value(1; "Faltan salidas")
    {
        Caption = 'Exits are missing', Comment = 'ESP="Faltan salidas"';
    }
    value(2; "Faltan consumos")
    {
        Caption = 'Consumption are missing', Comment = 'ESP="Faltan consumos"';
    }
    value(3; "Falta limpieza")
    {
        Caption = 'Lack of Cleaning Time', Comment = 'ESP="Falta tiempo de preparación (limpieza y preparación)"';
    }
    value(4; "Falta fabricacion")
    {
        Caption = 'Lack of Production Time', Comment = 'ESP="Falta tiempo de ejecución"';
    }
    value(5; "Faltan lineas")
    {
        Caption = 'Production Order Lines are Missing', Comment = 'ESP="Faltan líneas en la orden de producción"';
    }
    value(6; "Faltan componentes")
    {
        Caption = 'Production Order Components are Missing', Comment = 'ESP="Faltan componentes en la orden de producción"';
    }
    value(7; "Sobra limpieza")
    {
        Caption = 'Too Much Cleaning Time', Comment = 'ESP="Sobra tiempo de preparación (limpieza y preparación)"';
    }
    value(8; "Sobran consumos")
    {
        Caption = 'Too Much Consumption', Comment = 'ESP="Sobran consumos"';
    }
    value(9; "Sobran salidas")
    {
        Caption = 'Too Many Exits', Comment = 'ESP="Sobran salidas"';
    }
    value(10; "Sobra fabricacion")
    {
        Caption = 'Too Much Production Time', Comment = 'ESP="Sobra tiempo de ejecución"';
    }
    value(99; "No cerrar")
    {
        Caption = 'Do Not Close', Comment = 'ESP="No cerrar"';
    }
}
