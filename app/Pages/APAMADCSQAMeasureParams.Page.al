namespace MADCS.MADCS;

using Microsoft.Manufacturing.Setup;

page 55009 "APA MADCS QA. Measure Params."
{
    ApplicationArea = All;
    Caption = 'Quality Measure Parameters', Comment = 'ESP="Parámetros de Medida de Calidad"';
    PageType = List;
    SourceTable = "Quality Measure";
    UsageCategory = None;
    
    layout
    {
        area(Content)
        {
            repeater(General)
            {
            }
        }
    }
}
