namespace MADCS.MADCS;

/// <summary>
/// APA MADCS ButtonGroup ControlAddIn
/// Provides a customizable group of buttons for Manufacturing Automated Data Capture System scenarios.
/// </summary>
controladdin "APA MADCS ButtonGroup"
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
        'app/ControlAddIn/js/APAMADCSButton.js',
        'app/ControlAddIn/js/APAMADCSButtonGroup.js';
    StyleSheets =
        'app/ControlAddIn/css/APAMADCSBaseControl.css',
        'app/ControlAddIn/css/APAMADCSButton.css',
        'app/ControlAddIn/css/APAMADCSButtonGroup.css';
    StartupScript =
        'app/ControlAddIn/js/APAMADCSButtonGroupStartup.js';

    // Este controladdin proporciona un grupo reutilizable de botones para escenarios MADCS.

    #region Events
    /// <summary>
    /// Triggered when the control add-in is loaded and ready.
    /// </summary>
    event OnLoad();
    /// <summary>
    /// Triggered when an error occurs in the control add-in.
    /// </summary>
    /// <param name="message">Mensaje de error</param>
    event OnError(message: Text);
    /// <summary>
    /// Triggered when a button in the group is clicked.
    /// </summary>
    /// <param name="buttonId">El ID del botón pulsado</param>
    event OnClick(buttonId: Text);
    #endregion

    #region Procedures
    /// <summary>
    /// Adds a button to the group.
    /// </summary>
    /// <param name="caption">Texto del botón</param>
    /// <param name="title">Texto de ayuda</param>
    /// <param name="id">Identificador único del botón</param>
    /// <param name="type">Tipo de botón (primario, secundario, etc.)</param>
    procedure AddButton(caption: Text; title: Text; id: Text; "type": Text);

    /// <summary>
    /// Removes a button from the group by its ID.
    /// </summary>
    /// <param name="id">Identificador único del botón</param>
    procedure RemoveButton(id: Text);
    #endregion
}