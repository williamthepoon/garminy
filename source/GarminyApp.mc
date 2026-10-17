import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class GarminyApp extends Application.AppBase {
    var _view as CarouselView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new CarouselView();
        _view = view;
        return [view, new CarouselDelegate(view)];
    }

    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new GarminyGlance()];
    }

    function onSettingsChanged() as Void {
        if (_view != null) {
            (_view as CarouselView).reload();
        }
    }
}
