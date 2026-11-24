package openfl.display3D._internal;

#if (windows && cpp && lime && novaflare_render_attachment_trace)
import lime.graphics.opengl.GL.GLObject;

@:cppFileCode('
#include <windows.h>
#include <cstdio>
')
@:noCompletion
class RenderAttachmentTrace
{
	public static final enabled = Sys.getEnv("NOVAFLARE_RENDER_ATTACHMENT_TRACE") == "1";

	public static inline function objectId(object:GLObject):Int
	{
		if (object == null) return 0;
		return @:privateAccess object.id;
	}

	public static function qpc():cpp.Int64
	{
		untyped __cpp__('LARGE_INTEGER counter');
		return untyped __cpp__('QueryPerformanceCounter(&counter) ? counter.QuadPart : 0');
	}

	public static function write(event:String, begin:cpp.Int64, end:cpp.Int64, details:Dynamic):Void
	{
		var payload = haxe.Json.stringify(details);
		untyped __cpp__('std::printf("perf:%s begin_qpc=%llu end_qpc=%llu %s\\n", {0}.utf8_str(),
			static_cast<unsigned long long>({1}), static_cast<unsigned long long>({2}), {3}.utf8_str())',
			event, begin, end, payload);
		untyped __cpp__('std::fflush(stdout)');
	}
}
#end
