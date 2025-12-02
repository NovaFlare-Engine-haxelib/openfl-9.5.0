package openfl.events;

#if !flash
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class TextEditEvent extends Event
{
    public static inline var TEXT_EDIT:EventType<TextEditEvent> = "textEdit";

    public var text:String;
    public var start:Int;
    public var length:Int;

    public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, text:String = "", start:Int = 0, length:Int = 0)
    {
        super(type, bubbles, cancelable);
        this.text = text;
        this.start = start;
        this.length = length;
    }

    public override function clone():TextEditEvent
    {
        var event = new TextEditEvent(type, bubbles, cancelable, text, start, length);
        event.target = target;
        event.currentTarget = currentTarget;
        event.eventPhase = eventPhase;
        return event;
    }

    public override function toString():String
    {
        return __formatToString("TextEditEvent", ["type", "bubbles", "cancelable", "text", "start", "length"]);
    }

    @:noCompletion private override function __init():Void
    {
        super.__init();
        text = "";
        start = 0;
        length = 0;
    }
}
#else
typedef TextEditEvent = flash.events.Event;
#end

