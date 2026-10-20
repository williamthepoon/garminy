import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// Owns the enabled cards, rotation, pinning and the guarded exit.
// A single 1 s timer drives everything; the screen is redrawn only when
// something visible changes.
class CarouselView extends WatchUi.View {
    const HOLD_TO_EXIT_MS = 1000;
    const HINT_MS = 2000;

    var _cards as Array<Card> = [] as Array<Card>;
    var _idx as Number = 0;
    var _elapsed as Number = 0;      // seconds the current card has been shown
    var _interval as Number = 10;
    var _pinned as Boolean = false;
    var _timer as Timer.Timer?;
    var _lastMinute as Number = -1;
    var _hintUntil as Number = 0;
    var _escDownAt as Number? = null;
    var _layout as Layout?;
    var _backlight as Float = 0.0;
    var _quiet as Boolean = false;
    var _companion as Companion;
    var _link as Link;
    var _hasNews as Boolean = false;
    var _cardTick as Number = 0;     // seconds towards the current card's own tick

    function initialize(companion as Companion, link as Link) {
        View.initialize();
        _companion = companion;
        _link = link;
        _companion.onSettings = method(:applyRemoteSettings);
        reload();
    }

    // Rebuild from settings, keeping the current card if it is still enabled.
    function reload() as Void {
        var currentId = _cards.size() > 0 ? _cards[_idx].id() : null;
        var ids = Settings.enabledIds();
        var cards = [] as Array<Card>;
        var newIdx = 0;
        for (var i = 0; i < ids.size(); i++) {
            var c = null as Card?;
            if (ids[i].equals("agents")) {
                c = showAgents() ? new AgentsCard(_companion) : null;
            } else if (ids[i].equals("news")) {
                c = showNews() ? new NewsCard() : null;
            } else {
                c = makeCard(ids[i]);
            }
            if (c != null) {
                if (currentId != null && ids[i].equals(currentId)) {
                    newIdx = cards.size();
                }
                cards.add(c);
            }
        }
        _cards = cards;
        _idx = newIdx;
        // A newly current card counts as shown, so feed cards don't repeat their first item.
        if (cards.size() > 0 && (currentId == null || !cards[newIdx].id().equals(currentId))) {
            cards[newIdx].shown();
        }
        _hasNews = false;
        for (var i = 0; i < cards.size(); i++) {
            _hasNews = _hasNews || cards[i].id().equals("news");
        }
        _interval = Settings.interval();
        var level = Settings.backlightLevel();
        if (level == 0.0 && _backlight > 0.0) {
            setBacklight(false);
        }
        _backlight = level;
        _elapsed = 0;
        _pinned = false;
        if (Settings.companion()) {
            _link.start();
        } else if (_link.state != Link.OFF) {
            _link.stop();
        }
        refreshCurrent();
        WatchUi.requestUpdate();
    }

    // SETTINGS from the Mac: save if newer, then rebuild.
    function applyRemoteSettings(d as Dictionary) as Void {
        if (Settings.applyRemote(d)) {
            reload();
        }
    }

    // A change from Garmin Connect: stamp it and tell the Mac.
    function settingsChangedLocally() as Void {
        Settings.markChanged(_companion.macOffset);
        reload();
        _companion.sendSettings();
    }

    // The Agents card appears once a Mac companion has connected at least once.
    function showAgents() as Boolean {
        return Settings.companion() && _companion.everConnected;
    }

    // The News card appears once a full set of headlines has arrived (news-headlines).
    function showNews() as Boolean {
        return Settings.companion() && Feeds.get(Feeds.NEWS) != null;
    }

    function onShow() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        (_timer as Timer.Timer).start(method(:onTick), 1000, true);
        refreshCurrent();
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
    }

    function onTick() as Void {
        var dirty = false;
        _link.tick();
        if (showAgents() && Settings.agentsEnabled() && (_cards.size() == 0 || !_cards[0].id().equals("agents"))) {
            reload();
            return;
        }
        if (!_hasNews && Settings.newsEnabled() && showNews()) {
            reload();
            return;
        }
        var alerting = _companion.current() != null;

        if (_escDownAt != null && System.getTimer() - (_escDownAt as Number) >= HOLD_TO_EXIT_MS) {
            System.exit();
        }

        holdBacklight(Settings.quietNow());

        if (_hintUntil != 0 && System.getTimer() >= _hintUntil) {
            _hintUntil = 0;
            dirty = true;
        }

        var minute = System.getClockTime().min;
        if (minute != _lastMinute) {
            _lastMinute = minute;
            refreshCurrent();
            dirty = true;
        }

        if ((_pinned || _cards.size() == 1) && !alerting && _cards.size() > 0) {
            _cardTick += 1;
            if (_cardTick >= _interval) {
                _cardTick = 0;
                dirty = _cards[_idx].tick() || dirty;
            }
        } else {
            _cardTick = 0;
        }

        if (!_pinned && !alerting && _cards.size() > 1) {
            _elapsed += 1;
            if (_elapsed >= _interval) {
                show(_idx + 1);
                return;
            }
        }

        if (dirty) {
            WatchUi.requestUpdate();
        }
    }

    // Repeated calls hold the backlight on past the device timeout. Quiet hours switch it
    // off once, whatever the Backlight setting, then leave it to the device so a touch
    // still lights it briefly.
    function holdBacklight(quiet as Boolean) as Void {
        if (quiet) {
            if (!_quiet) {
                setBacklight(false);
            }
        } else if (_backlight > 0.0) {
            setBacklight(_backlight);
        }
        _quiet = quiet;
    }

    function setBacklight(setting as Boolean or Float) as Void {
        if (Attention has :backlight) {
            try {
                Attention.backlight(setting);
            } catch (e) {
                // AMOLED devices refuse long backlight holds; give up quietly.
                _backlight = 0.0;
            }
        }
    }

    function show(idx as Number) as Void {
        var n = _cards.size();
        if (n == 0) {
            return;
        }
        _idx = ((idx % n) + n) % n;
        _elapsed = 0;
        _cardTick = 0;
        _cards[_idx].shown();
        refreshCurrent();
        WatchUi.requestUpdate();
    }

    function next() as Void {
        _pinned = false;
        show(_idx + 1);
    }

    function prev() as Void {
        _pinned = false;
        show(_idx - 1);
    }

    // Tap: acknowledge a showing alert, otherwise pin or unpin.
    function tap() as Void {
        if (_companion.current() != null) {
            _companion.acknowledge();
            _elapsed = 0;
            return;
        }
        togglePin();
    }

    function togglePin() as Void {
        if (_cards.size() == 0) {
            return;
        }
        _pinned = !_pinned;
        _elapsed = 0;
        WatchUi.requestUpdate();
    }

    function escDown() as Void {
        _escDownAt = System.getTimer();
    }

    function escUp() as Void {
        var down = _escDownAt;
        _escDownAt = null;
        if (down != null && System.getTimer() - down >= HOLD_TO_EXIT_MS) {
            System.exit();
        }
        _hintUntil = System.getTimer() + HINT_MS;
        WatchUi.requestUpdate();
    }

    function refreshCurrent() as Void {
        if (_cards.size() > 0) {
            _cards[_idx].refresh();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (_layout == null) {
            _layout = new Layout(dc.getWidth(), dc.getHeight());
        }
        var l = _layout as Layout;
        dc.setColor(Ui.FG, Ui.BG);
        dc.clear();

        drawHeader(dc, l);

        if (_cards.size() == 0) {
            drawMessage(dc, l, "Enable cards in Garmin Connect");
        } else {
            _cards[_idx].draw(dc, l);
            drawDots(dc, l);
        }

        AlertOverlay.draw(dc, l, _companion);

        if (_hintUntil != 0) {
            drawHint(dc, l);
        }
    }

    function drawHeader(dc as Graphics.Dc, l as Layout) as Void {
        var t = System.getClockTime();
        var text = Ui.formatHm(t.hour, t.min);
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.headerY, Graphics.FONT_SMALL, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var tw = dc.getTextWidthInPixels(text, Graphics.FONT_SMALL);
        if (_pinned) {
            dc.setColor(Ui.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(l.cx + tw / 2 + 10, l.headerY, 4);
        }
        var dot = statusDotColor();
        if (dot != null) {
            dc.setColor(dot, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(l.cx - tw / 2 - 10, l.headerY, 4);
        }
    }

    // Companion status: grey while the link is down, else the most urgent session's colour.
    function statusDotColor() as Number? {
        if (!Settings.companion() || !_companion.everConnected) {
            return null;
        }
        if (!_companion.connected) {
            return Ui.FAINT;
        }
        var s = _companion.topState();
        return s == null ? null : Look.stateColor(s);
    }

    // One dot per card; the current card's dot is filled.
    function drawDots(dc as Graphics.Dc, l as Layout) as Void {
        var n = _cards.size();
        if (n < 2) {
            return;
        }
        var gap = 10;
        var x0 = l.cx - (n - 1) * gap / 2;
        for (var i = 0; i < n; i++) {
            if (i == _idx) {
                dc.setColor(_pinned ? Ui.ACCENT : Ui.FG, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * gap, l.dotsY, 3);
            } else {
                dc.setColor(Ui.FAINT, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * gap, l.dotsY, 2);
            }
        }
    }

    function drawHint(dc as Graphics.Dc, l as Layout) as Void {
        var bh = 30;
        var y = l.cy - bh / 2;
        dc.setColor(Ui.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(l.boxX, y, l.boxW, bh, 8);
        dc.setColor(Ui.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(l.cx, l.cy, Graphics.FONT_XTINY, "Hold BACK to exit",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class CarouselDelegate extends WatchUi.BehaviorDelegate {
    var _view as CarouselView;

    function initialize(view as CarouselView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // DOWN button or swipe up.
    function onNextPage() as Boolean {
        _view.next();
        return true;
    }

    // UP button or swipe down.
    function onPreviousPage() as Boolean {
        _view.prev();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _view.tap();
        return true;
    }

    // START on devices where it works; harmless when it doesn't.
    function onSelect() as Boolean {
        _view.tap();
        return true;
    }

    // Swallow the default exit; exiting is handled by holding BACK.
    function onBack() as Boolean {
        return true;
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ESC) {
            _view.escDown();
            return true;
        }
        return false;
    }

    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ESC) {
            _view.escUp();
            return true;
        }
        return false;
    }
}
