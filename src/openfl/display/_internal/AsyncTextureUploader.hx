package openfl.display._internal;

import lime.app.Application;
import lime.graphics.Image;
import lime.graphics.opengl.GL;
import lime.utils.UInt8Array;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.Context3D;

class AsyncTextureUploader {
	private var currentImage:Image;
	private var currentTexture:TextureBase;
	private var currentY:Int = 0;
	private var sliceHeight:Int = 0;
	private var onCompleteCallback:TextureBase->Void;
	private var isUploading:Bool = false;
	private var context:Context3D;

	public function new() {}

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
		this.sliceHeight = sliceSize > 0 ? sliceSize : 128;
		
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

		// 检查是否完成
		// currentY is a linear tile index. Deriving X/Y from one integer avoids
		// full-width GL transfers without adding another GC-visible state field.
		var tileSize = sliceHeight;
		var tilesPerRow = Std.int((currentImage.width + tileSize - 1) / tileSize);
		var tileRows = Std.int((currentImage.height + tileSize - 1) / tileSize);
		if (currentY >= tilesPerRow * tileRows) {
			finishUpload();
			return;
		}

		var gl = @:privateAccess context.gl;
		var tileX = (currentY % tilesPerRow) * tileSize;
		var tileY = Std.int(currentY / tilesPerRow) * tileSize;
		var w = currentImage.width - tileX;
		if (w > tileSize) w = tileSize;
		var h = currentImage.height - tileY;
		if (h > tileSize) h = tileSize;

		#if (cpp || neko)
		var UNPACK_ROW_LENGTH = 0x0CF2;
		var UNPACK_SKIP_ROWS = 0x0CF3;
		var UNPACK_SKIP_PIXELS = 0x0CF4;
		var UNPACK_ALIGNMENT = 0x0CF5;
		// Pixel-store settings are global context state. Other OpenFL uploads may
		// leave a full-image row stride behind; applying that stride to this
		// tightly packed tile reads past the source buffer in the NVIDIA worker.
		gl.pixelStorei(UNPACK_ROW_LENGTH, 0);
		gl.pixelStorei(UNPACK_SKIP_ROWS, 0);
		gl.pixelStorei(UNPACK_SKIP_PIXELS, 0);
		gl.pixelStorei(UNPACK_ALIGNMENT, 4);

		var bytesPerPixel = 4;
		var dataSize = w * h * bytesPerPixel;
		var source = currentImage.data;

		// Pack non-contiguous source rows and honor Image.data.byteOffset.
		var uploadBuffer = new UInt8Array(dataSize);
		for (row in 0...h) {
			var srcPos = ((tileY + row) * currentImage.width + tileX) * bytesPerPixel;
			var available = source.byteLength - srcPos;
			if (available <= 0) break;
			var rowSize = w * bytesPerPixel;
			if (rowSize > available) rowSize = available;
			uploadBuffer.set(source.subarray(srcPos, srcPos + rowSize), row * w * bytesPerPixel);
		}
		var BGRA_EXT = 0x80E1;
		var format = @:privateAccess TextureBase.__supportsBGRA ? BGRA_EXT : gl.RGBA;
		@:privateAccess context.__bindGLTexture2D(currentTexture.__textureID);
		// Lime's threaded native GL bridge blocks until texSubImage2D has consumed
		// this bounded client-memory tile. Avoiding PIXEL_UNPACK_BUFFER here is
		// important: replay/state reloads interleave other OpenFL uploads, and the
		// shared PBO binding was repeatedly crashing NVIDIA's worker thread.
		@:privateAccess lime.graphics.opengl.GL.texSubImage2D(gl.TEXTURE_2D, 0, tileX, tileY, w, h, format, gl.UNSIGNED_BYTE, uploadBuffer);
		@:privateAccess context.__bindGLTexture2D(null);
		
		#else
		@:privateAccess context.__bindGLTexture2D(currentTexture.__textureID);
		var subData = currentImage.data.subarray(0, 0); // Placeholder
		@:privateAccess context.__bindGLTexture2D(null);
		#end

		currentY++;
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
		if (isUploading) {
			Application.current.onUpdate.remove(onUpdate);
			isUploading = false;
		}
	}
}
