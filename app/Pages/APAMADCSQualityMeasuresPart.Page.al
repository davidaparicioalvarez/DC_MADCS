namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Quality Measures Part
/// Part page for managing Quality Measures in production orders.
/// This page will be used within the main MADCS card to display and manage output data.
/// </summary>
page 55008 "APA MADCS Quality MeasuresPart"
{
    // TODO:
    Caption = 'Quality Measures', Comment = 'ESP="Medidas de Calidad"';
    PageType = List;
    SourceTable = "Prod. Order Routing Line";
    Editable = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            grid(Columns)
            {
                group(RepeaterGrp)
                {
                    ShowCaption = false;
                    Editable = false;

                    repeater(Control1)
                    {
                        ShowCaption = false;

                    }
                }
                group(DataGrp)
                {
                    ShowCaption = false;

                }
            }
        }
    }

    var
}