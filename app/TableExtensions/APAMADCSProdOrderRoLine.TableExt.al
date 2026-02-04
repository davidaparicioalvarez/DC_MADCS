namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

tableextension 55006 "APA MADCS Prod. Order Ro. Line" extends "Prod. Order Routing Line"
{
    fields
    {
        field(55000; "Operation Type"; Enum "APA MADCS Operation Type")
        {
            Caption = 'Operation Type', Comment = 'ESP="Tipo de operación"';
            ToolTip = 'Specifies the MADCS operation type (Preparation, Execution, or Cleaning) for the production order routing line.', Comment = 'ESP="Especifica el tipo de operación MADCS (prepraración, ejecución o limpieza) para la línea de enrutamiento de la orden de producción."';
            DataClassification = SystemMetadata;
        }
    }
}
