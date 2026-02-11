namespace MADCS.MADCS;

enum 55004 "APA MADCS Buttons"
{
    Extensible = true;
    Caption = 'MADCS Buttons', Comment = 'ESP="Botones MADCS"';

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
    value(7; ALButtonFinalizeTasksTok)
    {
        Caption = 'ALButtonFinalizeTasks', Locked = true;
    }
    value(8; ALButtonFinalizeOutputTok)
    {
        Caption = 'ALButtonFinalizeOutput', Locked = true;
    }
    value(9; ALButtonFinalizeConsumptionTok)
    {
        Caption = 'ALButtonFinalizeConsumption', Locked = true;
    }
    value(10; ALButtonPostTok)
    {
        Caption = 'ALButtonPost', Locked = true;
    }
    value(11; ALButtonConsumeAllTok)
    {
        Caption = 'ALButtonConsumeAll', Locked = true;
    }
    value(12; ALButtonConsumeItemTok)
    {
        Caption = 'ALButtonConsumeItem', Locked = true;
    }
    value(13; ALButtonFinalizeMyTaskTok)
    {
        Caption = 'ALButtonFinalizeMyTask', Locked = true;
    }
}
