import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.Power
import qs.Services.System

ShellRoot {
  Component.onCompleted: {
    IdleService.init();
    ScreenTimeService.init();
  }

  IpcHandler {
    target: "screenTimeTest"

    function state(): string {
      return JSON.stringify({
        loaded: ScreenTimeService.isLoaded,
        tracking: ScreenTimeService.isTracking,
        app: ScreenTimeService.currentAppId,
        idle: ScreenTimeService.isUserIdle,
        total: ScreenTimeService.todayTotalSeconds,
        days: ScreenTimeService.days,
        path: ScreenTimeService.stateFilePath
      });
    }

    function load(data: string): void {
      ScreenTimeService._loadData(data);
    }

    function accrue(app: string, start: string, end: string): void {
      ScreenTimeService._accrueTime(app, app, "", "", Number(start), Number(end));
    }

    function stats(days: int): string {
      return JSON.stringify(ScreenTimeService.getRangeStats(days));
    }

    function rollback(seconds: int, now: string): void {
      ScreenTimeService._rollbackIdleSeconds(seconds, Number(now));
    }

    function save(): void {
      ScreenTimeService.forceSave();
    }
  }
}
