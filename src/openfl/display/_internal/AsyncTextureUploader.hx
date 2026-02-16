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
	private var currentX:Int = 0;
	private var sliceHeight:Int = 0;
	private var sliceWidth:Int = 0; // 新增：切片宽度
	private var onCompleteCallback:TextureBase->Void;
	private var isUploading:Bool = false;
	private var context:Context3D;

	public function new() {
		#if (cpp || neko)
		pbo = GL.createBuffer();
		#end
	}

	public function init(image:Image, context:Context3D, texture:TextureBase, sliceSize:Int = 128, ?onComplete:TextureBase->Void):Void {
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

		@:privateAccess context.__bindGLTexture2D(texture.__textureID);
		
		this.currentTexture = texture;
		this.currentImage = image;
		this.sliceHeight = sliceSize;
		this.sliceWidth = sliceSize;
		
		this.onCompleteCallback = onComplete;
		this.currentY = 0;
		this.currentX = 0;
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

		// 检查是否完成
		if (currentY >= currentImage.height) {
			finishUpload();
			return;
		}

		var gl = @:privateAccess context.gl;
		var remainingH = currentImage.height - currentY;
		var h = (remainingH > sliceHeight) ? sliceHeight : remainingH;
		
		// 水平切分逻辑
		var remainingW = currentImage.width - currentX;
		var w = (remainingW > sliceWidth) ? sliceWidth : remainingW;

		#if (cpp || neko)
		// PIXEL_UNPACK_BUFFER is 0x88EC
		var PIXEL_UNPACK_BUFFER = 0x88EC;
		gl.bindBuffer(PIXEL_UNPACK_BUFFER, pbo);

		var UNPACK_ROW_LENGTH = 0x0CF2;
		gl.pixelStorei(UNPACK_ROW_LENGTH, currentImage.width);
		
		// 计算起始位置
		var bytesPerPixel = 4;
		var startByte = (currentY * currentImage.width + currentX) * bytesPerPixel;
		
		if (w == currentImage.width) {
			// 连续内存模式 (Fast Path)
			var dataSize = w * h * bytesPerPixel;
			
			if (startByte + dataSize > currentImage.data.buffer.length) {
				dataSize = currentImage.data.buffer.length - startByte;
			}
			
			var pointer = new BytePointer(currentImage.data.buffer, startByte);
			@:privateAccess lime.graphics.opengl.GL.bufferData(PIXEL_UNPACK_BUFFER, dataSize, pointer, gl.STREAM_DRAW);
			
			gl.pixelStorei(UNPACK_ROW_LENGTH, 0); 
			
			var BGRA_EXT = 0x80E1;
			var format = @:privateAccess TextureBase.__supportsBGRA ? BGRA_EXT : gl.RGBA;
			
			@:privateAccess context.__bindGLTexture2D(currentTexture.__textureID);
			@:privateAccess lime.graphics.opengl.GL.texSubImage2D(gl.TEXTURE_2D, 0, currentX, currentY, w, h, format, gl.UNSIGNED_BYTE, cast 0);
			@:privateAccess context.__bindGLTexture2D(null);
			
		} else {
			var tempSize = w * h * bytesPerPixel;
			var tempBuffer = new UInt8Array(tempSize);
			var srcData = currentImage.data;
			
			for (i in 0...h) {
				var srcPos = ((currentY + i) * currentImage.width + currentX) * bytesPerPixel;
				var dstPos = i * w * bytesPerPixel;
				// copy 这一行
				var sub = srcData.subarray(srcPos, srcPos + w * bytesPerPixel);
				tempBuffer.set(sub, dstPos);
			}
			
			var pointer = new BytePointer(tempBuffer.buffer, 0);
			@:privateAccess lime.graphics.opengl.GL.bufferData(PIXEL_UNPACK_BUFFER, tempSize, pointer, gl.STREAM_DRAW);
			gl.pixelStorei(UNPACK_ROW_LENGTH, 0);
			
			var BGRA_EXT = 0x80E1;
			var format = @:privateAccess TextureBase.__supportsBGRA ? BGRA_EXT : gl.RGBA;
			
			@:privateAccess context.__bindGLTexture2D(currentTexture.__textureID);
			@:privateAccess lime.graphics.opengl.GL.texSubImage2D(gl.TEXTURE_2D, 0, currentX, currentY, w, h, format, gl.UNSIGNED_BYTE, cast 0);
			@:privateAccess context.__bindGLTexture2D(null);
		}

		gl.bindBuffer(PIXEL_UNPACK_BUFFER, 0);
		gl.pixelStorei(UNPACK_ROW_LENGTH, 0);
		
		#else
		@:privateAccess context.__bindGLTexture2D(currentTexture.__textureID);
		var subData = currentImage.data.subarray(0, 0); // Placeholder
		@:privateAccess context.__bindGLTexture2D(null);
		#end

		currentX += w;
		if (currentX >= currentImage.width) {
			currentX = 0;
			currentY += h;
		}
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
