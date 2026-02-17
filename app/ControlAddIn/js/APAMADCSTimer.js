
var timerObject = null;

// Signal that the control is ready when the script loads
try {
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady');
} catch (e) {
    console.error('Error invoking ControlAddInReady:', e);
}

function StartTimer(milliSeconds) {
    try {
        if (timerObject) {
            clearInterval(timerObject);
        }
        timerObject = window.setInterval(TimerAction, milliSeconds);
    } catch (e) {
        console.error('Error starting timer:', e);
    }
}

function StopTimer() {
    try {
        if (timerObject) {
            clearInterval(timerObject);
            timerObject = null;
        }
    } catch (e) {
        console.error('Error stopping timer:', e);
    }
}

function TimerAction() {
    try {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RefreshPage');
    } catch (e) {
        console.error('Error invoking RefreshPage:', e);
    }
}