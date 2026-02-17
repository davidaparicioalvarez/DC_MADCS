controladdin "APA MADCS Timer"
{
    Scripts = 'js/APAMADCSTimer.js';


    HorizontalShrink = true;
    HorizontalStretch = false;
    MinimumHeight = 10;
    MinimumWidth = 10;
    RequestedHeight = 10;
    RequestedWidth = 10;
    VerticalShrink = true;
    VerticalStretch = false;

    /// <summary>
    /// Starts the timer in the JavaScript control with the specified number of milliseconds. When the timer elapses, it triggers the TimerElapsed event.
    /// </summary>
    /// <param name="milliSeconds"></param>
    procedure StartTimer(milliSeconds: Integer);

    /// <summary>
    /// Stops the timer in the JavaScript control.
    /// </summary>
    /// <remarks>
    /// This method is called from the AL code to stop the timer when the page is being updated to prevent multiple triggers of the TimerElapsed event.
    /// </remarks>
    procedure StopTimer();

    event ControlAddInReady();

    event RefreshPage();
}