namespace MADCS.MADCS;

enum 55007 "APA MADCS Calc Based On"
{
    Extensible = true;
    
#pragma warning disable LC0045 // TODO: - Change to a standard implementation when available
    value(0; "Actual Output")
    {
        Caption = 'Actual Output', Locked = true;
    }
#pragma warning restore LC0045 // TODO: - Change to a standard implementation when available
    value(1; "Expected Output")
    {
        Caption = 'Expected Output', Locked = true;
    }
}
