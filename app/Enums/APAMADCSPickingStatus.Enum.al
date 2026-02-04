namespace MADCS.MADCS;

enum 55009 "APA MADCS Picking Status"
{
    Extensible = true;

    value(0; "")
    {
        Caption = '', Locked = true;
    }
    value(1; Pending)
    {
        Caption = 'Pending', Comment = 'ESP="No Iniciado"';
    }
    value(2; "Partialy Picked")
    {
        Caption = 'Partialy Picked', Comment = 'ESP="Picking parcial"';
    }
    value(3; "Totaly Picked")
    {
        Caption = 'Totaly Picked', Comment = 'ESP="Picking completo"';
    }    
}
