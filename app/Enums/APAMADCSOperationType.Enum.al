namespace MADCS.MADCS;

enum 55010 "APA MADCS Operation Type"
{
    Extensible = true;
    
    value(0; "")
    {
        Caption = '', Locked = true;
    }
    value(10; Preparation)
    {
        Caption = 'Preparation', Comment = 'ESP="Preparación"';
    }
    value(20; Execution)
    {
        Caption = 'Execution', Comment = 'ESP="Ejecución"';
    }
    value(30; Cleaning)
    {
        Caption = 'Cleaning', Comment = 'ESP="Limpieza"';
    }
}
