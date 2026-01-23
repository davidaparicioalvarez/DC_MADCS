namespace MADCS.MADCS;

enum 55004 "APA MADCS Time Buttons"
{
    Extensible = true;
    Caption = 'MADCS Time Buttons', Comment = 'ESP="Botones de tiempo MADCS"';

    value(0; "")
    {
        Caption = '', Locked = true;
    }
    value(1; ALButtonPreparationTok)
    {
        Caption = 'ALButtonPreparation', Locked = true;
    }
    value(2; ALButtonExecutionTok)
    {
        Caption = 'ALButtonExecution', Locked = true;
    }
    value(3; ALButtonCleaningTok)
    {
        Caption = 'ALButtonCleaning', Locked = true;
    }
    value(4; ALButtonBreakdownTok)
    {
        Caption = 'ALButtonBreakdown', Locked = true;
    }
    value(5; ALButtonBlockedBreakdownTok)
    {
        Caption = 'ALButtonBlockedBreakdown', Locked = true;
    }
    value(6; ALButtonEndTok)
    {
        Caption = 'ALButtonEnd', Locked = true;
    }
}
