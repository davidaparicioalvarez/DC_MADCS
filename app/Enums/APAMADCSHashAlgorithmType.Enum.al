namespace MADCS.MADCS;

enum 55006 "APA MADCS Hash Algorithm Type"
{
    Extensible = true;
    
#pragma warning disable LC0045 // TODO: - Change to a standard implementation when available
    value(0; MD5)
    {
        Caption = 'MD5', Locked = true;
    }
#pragma warning restore LC0045 // TODO: - Change to a standard implementation when available
    value(1; SHA1)
    {
        Caption = 'SHA1', Locked = true;
    }
    value(2; SHA256)
    {
        Caption = 'SHA256', Locked = true;
    }
    value(3; SHA384)
    {
        Caption = 'SHA384', Locked = true;
    }
    value(4; SHA512)
    {
        Caption = 'SHA512', Locked = true;
    }
}
