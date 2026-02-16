package openfl.display._internal;

import lime.app.Application;
import lime.graphics.Image;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLTexture;
#if (cpp || neko)
import lime.utils.BytePointer;
#end
import lime.utils.UInt8Array;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.Context3D;

class AsyncTextureUploader {
	private var pbo:GLBuffer;
	private var currentImage:Image;
	private var currentTexture:TextureBase;
	private var currentY:Int = 0;
	private var sliceHeight:Int = 0;
	private var onCompleteCallback:TextureBase->Void;
	private var isUploading:Bool = false;
	private var context:Context3D;

	public function new() {
		#if (cpp || neko)
		pbo = GL.createBuffer();
		#end
	}

	public function init(image:Image, context:Context3D, texture:TextureBase, sliceHeight:Int = 128, ?onComplete:TextureBase->Void):Void {
		if (isUploading) {
			// trace("⚠️ AsyncTextureUploader busy!");
			return;
		}

		if (image == null) {
			// trace("❌ Image is null!");
			return;
		}

		this.context = context;
		var gl = @:privateAccess context.gl;

		// 确保纹理已绑定
		@:privateAccess context.__bindGLTexture2D(texture.__textureID);
		
		// 必须设置参数
		// gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		// gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		// gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		// gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

		this.currentTexture = texture;
		this.currentImage = image;
		this.sliceHeight = sliceHeight;
		this.onCompleteCallback = onComplete;
		this.currentY = 0;
		this.isUploading = true;

		var BGRA_EXT = 0x80E1; // Standard OpenGL value for GL_BGRA_EXT
		var format = @:privateAccess TextureBase.__supportsBGRA ? BGRA_EXT : gl.RGBA;
		
		// 预分配显存
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, image.width, image.height, 0, format, gl.UNSIGNED_BYTE, null);
		
		@:privateAccess context.__bindGLTexture2D(null);

		Application.current.onUpdate.add(onUpdate);
	}

	private function onUpdate(deltaTime:Float):Void {
		if (!isUploading) return;

		if (currentY >= currentImage.height) {
			finishUpload();
			return;
		}

		var gl = @:privateAccess context.gl;
		var remaining = currentImage.height - currentY;
		var h = (remaining > sliceHeight) ? sliceHeight : remaining;

		#if (cpp || neko)
		// PIXEL_UNPACK_BUFFER is 0x88EC
		var PIXEL_UNPACK_BUFFER = 0x88EC;
		gl.bindBuffer(PIXEL_UNPACK_BUFFER, pbo);

		var bytesPerPixel = 4; // RGBA
		var stride = currentImage.width * bytesPerPixel;
		var startByte = currentY * stride;
		var dataSize = h * stride;

		// 确保数据不会越界
		if (startByte + dataSize > currentImage.data.buffer.length) {
			dataSize = currentImage.data.buffer.length - startByte;
		}

		var pointer = new BytePointer(currentImage.data.buffer, startByte);
		
		@:privateAccess lime.graphics.opengl.GL.bufferData(PIXEL_UNPACK_BUFFER, dataSize, pointer, gl.STREAM_DRAW);

		var BGRA_EXT = 0x80E1; // Standard OpenGL value for GL_BGRA_EXT
		var format = @:privateAccess TextureBase.__supportsBGRA ? BGRA_EXT : gl.RGBA;

		@:privateAccess context.__bindGLTexture2D(currentTexture.__textureID);
		
		@:privateAccess lime.graphics.opengl.GL.texSubImage2D(gl.TEXTURE_2D, 0, 0, currentY, currentImage.width, h, format, gl.UNSIGNED_BYTE, cast 0);
		
		@:privateAccess context.__bindGLTexture2D(null);

		gl.bindBuffer(PIXEL_UNPACK_BUFFER, 0);
		#else
		// Fallback
		@:privateAccess context.__bindGLTexture2D(currentTexture.__textureID);
		var stride = currentImage.width * 4;
		var start = currentY * stride;
		var end = start + (h * stride);
		var subData = currentImage.data.subarray(start, end);
		gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, currentY, currentImage.width, h, gl.RGBA, gl.UNSIGNED_BYTE, subData);
		@:privateAccess context.__bindGLTexture2D(null);
		#end

		currentY += h;
	}

	private function finishUpload():Void {
		isUploading = false;
		Application.current.onUpdate.remove(onUpdate);
		
		var tex = currentTexture;
		currentImage = null;
		currentTexture = null;

		if (onCompleteCallback != null) {
			onCompleteCallback(tex);
		}
	}

	public function dispose():Void {
		#if (cpp || neko)
		if (pbo != null) {
			var gl = @:privateAccess context.gl;
			gl.deleteBuffer(pbo);
			pbo = null;
		}
		#end
		if (isUploading) {
			Application.current.onUpdate.remove(onUpdate);
			isUploading = false;
		}
	}
}
