namespace MADCS.MADCS;

/// <summary>
/// APA MADCS Button ControlAddIn
/// Provides a customizable button for Manufacturing Automated Data Capture System scenarios.
/// </summary>
controladdin "APA MADCS Button"
{
    RequestedHeight = 36;
    MinimumHeight = 32;
    MinimumWidth = 84;
    VerticalStretch = false;
    HorizontalStretch = true;
    VerticalShrink = true;
    HorizontalShrink = true;

    Scripts =
        'app/ControlAddIn/js/APAMADCSBaseControl.js',
        'app/ControlAddIn/js/APAMADCSButton.js';
    StyleSheets =
        'app/ControlAddIn/css/APAMADCSBaseControl.css',
        'app/ControlAddIn/css/APAMADCSButton.css';
    StartupScript =
        'app/ControlAddIn/js/APAMADCSButtonStartup.js';

    // This controladdin provides a reusable button for posting and other actions in MADCS scenarios.

    #region Events
    /// <summary>
    /// Triggered when the control add-in is loaded and ready.
    /// </summary>
    event OnLoad();

    /// <summary>
    /// Triggered when an error occurs in the control add-in.
    /// </summary>
    /// <param name="message">Error message</param>
    event OnError(message: Text);

    /// <summary>
    /// Triggered when the button is clicked.
    /// </summary>
    /// <param name="buttonId">The ID of the button clicked</param>
    event OnClick(buttonId: Text);
    #endregion

    #region Procedures
    /// <summary>
    /// Sets an option for the button control (for example, caption, enabled state, etc).
    /// </summary>
    /// <param name="key">Option key</param>
    /// <param name="value">Option value</param>
    procedure SetOption("key": Text; "value": Text);
    #endregion
}