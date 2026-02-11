namespace MADCS.MADCS;

using Microsoft.Inventory.Journal;
using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS ADCS User
/// Permission set for ADCS users to access MADCS extension objects.
/// </summary>
permissionset 55000 "APA MADCS ADCS User"
{
    Caption = 'MADCS ADCS User', MaxLength = 30, Comment = 'ESP="Usuario ADCS MADCS"';
    Permissions =
        tabledata "APA MADCS User Log" = RIMD,
        tabledata "Item Journal Line" = RIMD,
        tabledata "APA MADCS Pro. Order Line Time" = RIMD,
        tabledata "Production Order" = R,
        tabledata "Prod. Order Component" = RIMD,
        tabledata "DC Errores Cierre Orden" = RMID,
        tabledata "DC Tolerancias Admitidas" = RMID,
        table "APA MADCS User Log" = X,
        table "APA MADCS Pro. Order Line Time" = X,
        codeunit "APA MADCS Management" = X,
        codeunit "DC Prod. Order. Close Errores" = X,
        page "APA MADCS Rel Prod Order Lines" = X,
        page "APA MADCS Consumption" = X,
        page "APA MADCS Outputs" = X,
        page "APA MADCS Time Part" = X,
        page "APA MADCS Lot No. Information" = X,
        page "APA MADCS Verification" = X,
        page "APA MADCS Quality Measures" = X,
        page "APA MADCS Consume Components" = X,
        page "APA MADCS QA. Measure Params." = X,
        page "APA MADCS Track. Specification" = X,
        page "APA MADCS Role Center" = X,
        report "APA MADCS Close Prod. Orders" = X;
}
