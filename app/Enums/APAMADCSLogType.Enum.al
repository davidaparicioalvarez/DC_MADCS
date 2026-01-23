namespace MADCS.MADCS;

enum 55005 "APA MADCS Log Type"
{
    Extensible = true;
    
    value(0; "")
    {
        Caption = '', Locked = true;
    }
    value(1; Consum)
    {
        Caption = 'Consum', Comment = 'ESP="Consumo"';
    }
    value(2; Output)
    {
        Caption = 'Output', Comment = 'ESP="Salida"';
    }
    value(3; Fault)
    {
        Caption = 'Fault', Comment = 'ESP="Avería"';
    }
    value(4; Execution)
    {
        Caption = 'Execution Task', Comment = 'ESP="Tarea Ejecución"';
    }
    value(5; Cleaning)
    {
        Caption = 'Cleaning Task', Comment = 'ESP="Tarea Limpieza"';
    }
    value(6; FinalizeTask)
    {
        Caption = 'Finalize Task', Comment = 'ESP="Finalizar Tarea"';
    }
    value(7; PostTime)
    {
        Caption = 'Post Time', Comment = 'ESP="Registrar Tiempo"';
    }
}
