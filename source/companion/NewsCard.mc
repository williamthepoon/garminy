import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

const NEWS_STALE = 12 * 3600;

// Headlines from the Mac's RSS feed, with source and age below (news-headlines).
class NewsCard extends FeedCard {
    function initialize() {
        FeedCard.initialize(Feeds.NEWS, Graphics.FONT_SMALL);
    }

    function id() as String {
        return "news";
    }

    function meta(item as Array) as Array? {
        var s = Feeds.get(Feeds.NEWS);
        var now = Time.now().value();
        if (s != null && now - (s["receivedAt"] as Number) > NEWS_STALE) {
            return ["Out of date", Ui.RED];
        }
        return [newsMeta(item[1] as String, item[0] as Number?, now), Ui.FG];
    }
}

// "Sky News · 25m", or just the source without a publish time.
function newsMeta(source as String, published as Number?, now as Number) as String {
    if (published == null) {
        return source;
    }
    var age = ageText(now - published > 0 ? now - published : 0);
    return source.length() > 0 ? source + " · " + age : age;
}
