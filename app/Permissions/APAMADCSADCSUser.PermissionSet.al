namespace MADCS.MADCS;

/// <summary>
/// APA MADCS ADCS User
/// Permission set for ADCS users to access MADCS extension objects.
/// </summary>
permissionset 55000 "APA MADCS ADCS User"
{
    Caption = 'MADCS ADCS User', MaxLength = 30, Comment = 'ESP="Usuario ADCS MADCS"';
    Permissions =
        tabledata "APA MADCS User Log" = RIMD,
        tabledata Microsoft.Inventory.Journal."Item Journal Line" = RIMD,
        tabledata "APA MADCS Pro. Order Line Time" = RIMD,
        tabledata Microsoft.Manufacturing.Document."Production Order" = R,
        tabledata Microsoft.Manufacturing.Document."Prod. Order Component" = RIMD,
        table "APA MADCS User Log" = X,
        table "APA MADCS Pro. Order Line Time" = X,
        codeunit "APA MADCS Management" = X,
        page "APA MADCS Rel Prod Order Lines" = X,
        page "APA MADCS Consumption Part" = X,
        page "APA MADCS Outputs Part" = X,
        page "APA MADCS Time Part" = X,
        page "APA MADCS Lot No. Information" = X,
        page "APA MADCS Verification Part" = X,
        page "APA MADCS Quality MeasuresPart" = X,
        page "APA MADCS Consume Components" = X,
        page "APA MADCS QA. Measure Params." = X,
        page "APA MADCS Track. Specification" = X,
        report "APA MADCS Close Prod. Orders" = X;
}
