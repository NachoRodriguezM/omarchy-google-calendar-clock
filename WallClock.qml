import QtQuick
import "Model.js" as Model

// Epoch-aligned clock: local wall-clock targets can repeat during the
// daylight-saving fall-back hour, causing a timer to rearm continuously.
Timer {
  id: root

  property int step: 60000
  property date date: new Date()

  function arm() {
    interval = Model.msUntilNextTick(Date.now(), step)
    restart()
  }

  onStepChanged: arm()
  onTriggered: {
    date = new Date()
    arm()
  }
  Component.onCompleted: arm()
}
