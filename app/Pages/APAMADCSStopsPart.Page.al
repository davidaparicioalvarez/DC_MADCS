namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Stops Part
/// Part page for managing Stops in production orders.
/// This page will be used within the main MADCS card to display and manage output data.
/// </summary>
page 55007 "APA MADCS Stops Part"
{
    // TODO:
    Caption = 'Stops', Comment = 'ESP="Paradas"';
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