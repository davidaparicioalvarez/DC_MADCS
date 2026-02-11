namespace MADCS.MADCS;

/// <summary>
/// Page APA MADCS Role Center (ID 55011).
/// </summary>
page 55011 "APA MADCS Role Center"
{
    Caption = 'MADCS Role Center', Comment = 'ESP="MADCS Role Center"';
    PageType = RoleCenter;
    Extensible = true;
    ApplicationArea = All;

    layout
    {
        area(RoleCenter)
        {
        }
    }
    actions
    {
        area(Creation) // Action bar left side
        {
        }
        area(Processing) // Action bar right side
        {
            action(MADCS)
            {
                Caption = 'MADCS', Comment = 'ESP="MADCS"';
                ToolTip = 'Access to the MADCS functionality.', Comment = 'ESP="Acceso a la funcionalidad de MADCS."';
                Image = "8ball";
                ApplicationArea = All;
                RunObject = page "APA MADCS Rel Prod Order Lines";
            }
        }
        area(Reporting) // Action bar right down side, reports
        {
        }
        area(Embedding) // Navigation bar
        {
        }
        area(Sections) // Navigation menus
        {
        }
    }
}