package openfl.display3D._internal;

#if (cpp && lime)
import lime.utils.Int32Array;
import lime._internal.backend.native.NativeCFFI;
import openfl.Vector;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AGALMiniAssembler;
import openfl.utils._internal.Log;

@:access(openfl.display3D.Context3D)
@:access(openfl.display3D._internal.Context3DState)
@:access(openfl.display3D.textures.TextureBase)
class StageRenderTarget
{
	public var active(default, null):Bool = false;
	public var presenting(default, null):Bool = false;
	public var scaleX(default, null):Float;
	public var scaleY(default, null):Float;
	public var drawableWidth(default, null):Int = 0;
	public var drawableHeight(default, null):Int = 0;

	final context:Context3D;
	var texture:RectangleTexture;
	var framebuffer:GLFramebuffer;
	var screenFramebuffer:GLFramebuffer;
	var compositeProgram:Program3D;
	var compositeState:Context3DState;
	var vertices:VertexBuffer3D;
	var indices:IndexBuffer3D;
	var width:Int = 0;
	var height:Int = 0;
	var actualWidth:Int = 0;
	var actualHeight:Int = 0;
	var reportPending:Bool = false;
	var trace:Bool = false;
	var mode:String;

	public function new(context:Context3D)
	{
		this.context = context;
	}

	public function begin(boundsWidth:Int, boundsHeight:Int, trace:Bool):Bool
	{
		var outputWidth = Std.int(context.__stage.window.width * context.__stage.window.scale);
		var outputHeight = Std.int(context.__stage.window.height * context.__stage.window.scale);
		if (outputWidth <= 0 || outputHeight <= 0) return false;

		if (trace && (!this.trace || outputWidth != drawableWidth || outputHeight != drawableHeight)) reportPending = true;
		this.trace = trace;
		drawableWidth = outputWidth;
		drawableHeight = outputHeight;

		var ratio = Math.min(1, Math.min(boundsWidth / outputWidth, boundsHeight / outputHeight));
		var targetWidth = Std.int(Math.max(1, Math.round(outputWidth * ratio)));
		var targetHeight = Std.int(Math.max(1, Math.round(outputHeight * ratio)));
		if (boundsWidth <= 0 || boundsHeight <= 0 || (targetWidth == outputWidth && targetHeight == outputHeight))
		{
			if (width != 0 || height != 0) dispose();
			setMode('native');
			return false;
		}

		if (width != targetWidth || height != targetHeight)
			allocate(targetWidth, targetHeight);
		if (framebuffer == null)
		{
			setMode('fallback');
			return false;
		}

		setMode('scaled');
		scaleX = width / drawableWidth;
		scaleY = height / drawableHeight;
		screenFramebuffer = context.__state.__primaryGLFramebuffer;
		context.setRenderToBackBuffer();
		context.__state.__primaryGLFramebuffer = framebuffer;
		active = true;
		return true;
	}

	function allocate(targetWidth:Int, targetHeight:Int):Void
	{
		release();
		width = targetWidth;
		height = targetHeight;
		var gl = context.gl;
		var nativeFramebuffer = context.__state.__primaryGLFramebuffer;
		try
		{
			var limit = Math.min(gl.getParameter(gl.MAX_TEXTURE_SIZE), gl.getParameter(gl.MAX_RENDERBUFFER_SIZE));
			if (width > limit || height > limit) throw new haxe.Exception('Framebuffer exceeds device limits');
			texture = context.createRectangleTexture(width, height, BGRA, true);
			framebuffer = texture.__getGLFramebuffer(true, 0, 0);
			context.__bindGLFramebuffer(framebuffer);
			if (framebuffer == null || gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
				throw new haxe.Exception('Framebuffer incomplete');
			if (trace) readAttachmentSize();
			if (compositeProgram == null) createComposite();
			reportPending = trace;
		}
		catch (error:haxe.Exception)
		{
			Log.warn('Render target ${width}x${height} unavailable: ${error.message}');
			if (texture != null) texture.dispose();
			disposeComposite();
			texture = null;
			framebuffer = null;
		}
		context.__bindGLFramebuffer(nativeFramebuffer);
	}

	function readAttachmentSize():Void
	{
		var gl = context.gl;
		#if lime_cffi
		var textureId = texture.__textureID;
		var colorName = @:privateAccess NativeCFFI.lime_gl_get_framebuffer_attachment_parameteri(gl.FRAMEBUFFER,
			gl.COLOR_ATTACHMENT0, gl.FRAMEBUFFER_ATTACHMENT_OBJECT_NAME);
		if (textureId == null || colorName != @:privateAccess textureId.id) return;
		var previous = context.__contextState.__currentGLTexture2D;
		context.__bindGLTexture2D(textureId);
		try
		{
			actualWidth = @:privateAccess NativeCFFI.lime_gl_get_tex_level_parameteri(gl.TEXTURE_2D, 0, 0x1000);
			actualHeight = @:privateAccess NativeCFFI.lime_gl_get_tex_level_parameteri(gl.TEXTURE_2D, 0, 0x1001);
		}
		catch (_:haxe.Exception)
		{
			actualWidth = 0;
			actualHeight = 0;
		}
		context.__bindGLTexture2D(previous);
		#end
	}

	public function reportViewport():Void
	{
		if (!reportPending || !trace) return;
		reportPending = false;
		if (active && (actualWidth != width || actualHeight != height)) readAttachmentSize();
		var viewport:Int32Array = context.gl.getParameter(context.gl.VIEWPORT);
		var size = !active ? 'default' : (actualWidth > 0 && actualHeight > 0 ? '${actualWidth}x$actualHeight' : 'unavailable');
		Sys.println('perf:render_target mode=$mode framebuffer=$size '
			+ 'allocated=${width}x$height viewport=${viewport[2]}x${viewport[3]} drawable=${drawableWidth}x$drawableHeight '
			+ 'viewport_origin=${viewport[0]},${viewport[1]}');
	}

	function setMode(value:String):Void
	{
		if (mode == value) return;
		mode = value;
		reportPending = trace;
	}

	public function finish(present:Bool):Void
	{
		if (!active) return;
		active = false;
		context.__state.__primaryGLFramebuffer = screenFramebuffer;
		context.setRenderToBackBuffer();
		if (!present)
		{
			restoreViewport();
			return;
		}
		presenting = true;
		var stageState = context.__state;
		compositeState.__primaryGLFramebuffer = screenFramebuffer;
		context.__state = compositeState;
		try
		{
			composite();
		}
		catch (error:haxe.Exception)
		{
			context.__state = stageState;
			presenting = false;
			restoreViewport();
			throw error;
		}
		context.__state = stageState;
		presenting = false;
	}

	function createComposite():Void
	{
		var vertex = new AGALMiniAssembler();
		vertex.assemble(Context3DProgramType.VERTEX, "mov op, va0\nmov v0, va1");
		var fragment = new AGALMiniAssembler();
		fragment.assemble(Context3DProgramType.FRAGMENT, "tex ft0, v0, fs0 <2d,linear,clamp,nomip>\nmov oc, ft0");
		compositeProgram = context.createProgram();
		compositeProgram.upload(vertex.agalcode, fragment.agalcode);
		vertices = context.createVertexBuffer(4, 5);
		vertices.uploadFromVector(Vector.ofArray([
			-1.0, -1.0, 0.0, 0.0, 0.0,
			 1.0, -1.0, 0.0, 1.0, 0.0,
			 1.0,  1.0, 0.0, 1.0, 1.0,
			-1.0,  1.0, 0.0, 0.0, 1.0
		]), 0, 4);
		indices = context.createIndexBuffer(6);
		indices.uploadFromVector(Vector.ofArray([0, 1, 2, 0, 2, 3]), 0, 6);
		compositeState = new Context3DState();
	}

	function composite():Void
	{
		context.setProgram(compositeProgram);
		context.setBlendFactors(ONE, ZERO);
		context.setColorMask(true, true, true, true);
		context.setCulling(NONE);
		context.setDepthTest(false, ALWAYS);
		context.setStencilActions();
		context.setStencilReferenceValue(0, 0, 0);
		context.setScissorRectangle(null);
		context.setTextureAt(0, texture);
		context.setVertexBufferAt(0, vertices, 0, FLOAT_3);
		context.setVertexBufferAt(1, vertices, 3, FLOAT_2);
		context.drawTriangles(indices);
	}

	function restoreViewport():Void
	{
		context.__flushGLFramebuffer();
		context.__flushGLViewport();
	}

	public function dispose():Void
	{
		finish(false);
		release();
		disposeComposite();
	}

	function disposeComposite():Void
	{
		if (compositeProgram != null) compositeProgram.dispose();
		if (vertices != null) vertices.dispose();
		if (indices != null) indices.dispose();
		compositeProgram = null;
		vertices = null;
		indices = null;
		compositeState = null;
	}

	function release():Void
	{
		if (texture != null) texture.dispose();
		texture = null;
		framebuffer = null;
		width = 0;
		height = 0;
		actualWidth = 0;
		actualHeight = 0;
	}
}
#end
