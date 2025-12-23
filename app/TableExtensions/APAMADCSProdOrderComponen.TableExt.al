/// <summary>
/// APA MADCS Prod. Order Component Extension
/// Extends the Prod. Order Component table to add ADCS-related functionality for automated data capture system.
/// This extension adds fields to track quantities captured through the ADCS system.
/// </summary>
tableextension 55002 "APA MADCS Prod. Order Componen" extends "Prod. Order Component"
{
    fields
    {
        field(55000; "MADCS Quantity"; Decimal)
        {
            Caption = 'Quantity', Comment = 'ESP="Cantidad"';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the quantity captured through the Automated Data Capture System (MADCS).', Comment = 'ESP="Especifica la cantidad capturada a través del Sistema Automatizado de Captura de Datos (MADCS)."';
            DecimalPlaces = 0 : 5;
        }

        field(55001; "MADCS Lot No."; Code[50])
        {
            Caption = 'Lot No.', Comment = 'ESP="Nº Lote"';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the lot number captured through the Automated Data Capture System (MADCS).', Comment = 'ESP="Especifica el número de lote capturado a través del Sistema Automatizado de Captura de Datos (MADCS)."';
        }
        field(55002; "MADCS Verified"; Boolean)
        {
            Caption = 'Verified', Comment = 'ESP="Verificado"';
            DataClassification = SystemMetadata;
            ToolTip = 'Indicates whether the MADCS data has been verified.', Comment = 'ESP="Indica si los datos de MADCS han sido verificados."';
        }
        field(55003; "Original Line No."; Integer)
        {
            Caption = 'Original Line No.', Comment = 'ESP="Nº Línea Original"';
            DataClassification = SystemMetadata;
            AllowInCustomizations = Never;
            ToolTip = 'Stores the original line number before any modifications.', Comment = 'ESP="Almacena el número de línea original antes de cualquier modificación."';
        }
    }
}
