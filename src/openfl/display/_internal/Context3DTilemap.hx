package openfl.display._internal;

#if !flash
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.OpenGLRenderer;
import openfl.display.Shader;
import openfl.display.TileContainer;
import openfl.display.Tilemap;
import openfl.display.Tileset;
import openfl.display.Tileset.TileData;
import openfl.display3D.Context3D;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

private typedef TileBufferContext =
{
	final parentTransform:Matrix;
	final tileset:Tileset;
	final alpha:Float;
	final colorTransform:ColorTransform;
}

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.VertexBuffer3D)
@:access(openfl.display.Shader)
@:access(openfl.display.Tilemap)
@:access(openfl.display.Tileset)
@:access(openfl.display.Tile)
@:access(openfl.filters.BitmapFilter)
@:access(openfl.geom.ColorTransform)
@:access(openfl.geom.Matrix)
@:access(openfl.geom.Rectangle)
@SuppressWarnings("checkstyle:FieldDocComment")
class Context3DTilemap
{
	private static final tileVertices = new Context3DTileVertices();
	private static var cacheColorTransform:ColorTransform;
	private static var context:Context3D;
	private static var dataPerVertex:Int;
	private static var currentBitmapData:BitmapData;
	private static var currentBlendMode:BlendMode;
	private static var currentShader:Shader;
	private static var bufferPosition:Int;
	private static var lastFlushedPosition:Int;
	private static var lastUsedBitmapData:BitmapData;
	private static var lastUsedShader:Shader;
	private static var numTiles:Int;

	public static function buildBuffer(tilemap:Tilemap, renderer:OpenGLRenderer):Void
	{
		numTiles = 0;
		if (!tilemap.__renderable || tilemap.__group.__tiles.length == 0 || tilemap.__worldAlpha <= 0)
		{
			// TODO: Use dirty to perform sparse update of buffers?
			// This is required here because `openfl.display.Tilemap` sets dirty on enter_frame
			tilemap.__group.__dirty = false;
			return;
		}

		var rect = Rectangle.__pool.get();
		var parentTransform = Matrix.__pool.get();
		tileVertices.reset(tilemap.tileAlphaEnabled, tilemap.tileColorTransformEnabled);
		final buildContext:TileBufferContext = {
			parentTransform: parentTransform,
			tileset: tilemap.__tileset,
			alpha: tilemap.__worldAlpha,
			colorTransform: tilemap.__worldColorTransform
		};
		buildBufferTileContainer(tilemap.__group, buildContext, renderer.__roundPixels, rect);
		numTiles = tileVertices.tileCount;
		dataPerVertex = tileVertices.stride;
		if (numTiles > 0)
		{
			resizeBuffer(tilemap, numTiles);
			tilemap.__buffer.uploadTiles(tileVertices);
		}

		Rectangle.__pool.release(rect);
		Matrix.__pool.release(parentTransform);
	}

	private static function buildBufferTileContainer(group:TileContainer, buildContext:TileBufferContext, roundPixels:Bool, rect:Rectangle):Void
	{
		var tileTransform = Matrix.__pool.get();
		var tiles = group.__tiles;
		final alphaEnabled = tileVertices.alphaEnabled;
		final colorTransformEnabled = tileVertices.colorTransformEnabled;
		final defaultColorTransform = buildContext.colorTransform;

		var tileset:Tileset;
		var alpha:Float;
		var visible:Bool;
		var colorTransform:ColorTransform = null;
		var id:Int;
		var tileData:TileData;
		var tileRect:Rectangle;
		var bitmapData:BitmapData;
		var uvX:Float;
		var uvY:Float;
		var uvHeight:Float;
		var uvWidth:Float;

		for (tile in tiles)
		{
			tileTransform.setTo(1, 0, 0, 1, -tile.originX, -tile.originY);
			tileTransform.concat(tile.matrix);
			tileTransform.concat(buildContext.parentTransform);

			if (roundPixels)
			{
				tileTransform.tx = Math.round(tileTransform.tx);
				tileTransform.ty = Math.round(tileTransform.ty);
			}

			tileset = tile.tileset != null ? tile.tileset : buildContext.tileset;

			alpha = tile.alpha * buildContext.alpha;
			visible = tile.visible;
			tile.__dirty = false;

			if (!visible || alpha <= 0) continue;

			if (colorTransformEnabled)
			{
				if (tile.colorTransform != null)
				{
					if (defaultColorTransform == null)
					{
						colorTransform = tile.colorTransform;
					}
					else
					{
						if (cacheColorTransform == null)
						{
							cacheColorTransform = new ColorTransform();
						}

						colorTransform = cacheColorTransform;
						colorTransform.redMultiplier = defaultColorTransform.redMultiplier * tile.colorTransform.redMultiplier;
						colorTransform.greenMultiplier = defaultColorTransform.greenMultiplier * tile.colorTransform.greenMultiplier;
						colorTransform.blueMultiplier = defaultColorTransform.blueMultiplier * tile.colorTransform.blueMultiplier;
						colorTransform.alphaMultiplier = defaultColorTransform.alphaMultiplier * tile.colorTransform.alphaMultiplier;
						colorTransform.redOffset = defaultColorTransform.redOffset + tile.colorTransform.redOffset;
						colorTransform.greenOffset = defaultColorTransform.greenOffset + tile.colorTransform.greenOffset;
						colorTransform.blueOffset = defaultColorTransform.blueOffset + tile.colorTransform.blueOffset;
						colorTransform.alphaOffset = defaultColorTransform.alphaOffset + tile.colorTransform.alphaOffset;
					}
				}
				else
				{
					colorTransform = defaultColorTransform;
				}
			}

			if (!alphaEnabled) alpha = 1;

			if (tile.__length > 0)
			{
				buildBufferTileContainer(cast tile, {
					parentTransform: tileTransform,
					tileset: tileset,
					alpha: alpha,
					colorTransform: colorTransform
				}, roundPixels, rect);
			}
			else
			{
				if (tileset == null) continue;

				id = tile.id;

				bitmapData = tileset.__bitmapData;
				if (bitmapData == null) continue;

				if (id == -1)
				{
					tileRect = tile.__rect;
					if (tileRect == null || tileRect.width <= 0 || tileRect.height <= 0) continue;

					uvX = tileRect.x / bitmapData.width;
					uvY = tileRect.y / bitmapData.height;
					uvWidth = tileRect.right / bitmapData.width;
					uvHeight = tileRect.bottom / bitmapData.height;
				}
				else
				{
					tileData = tileset.__data[id];
					if (tileData == null) continue;

					rect.setTo(tileData.x, tileData.y, tileData.width, tileData.height);
					tileRect = rect;

					uvX = tileData.__uvX;
					uvY = tileData.__uvY;
					uvWidth = tileData.__uvWidth;
					uvHeight = tileData.__uvHeight;
				}

				tileVertices.appendGeometry(tileTransform, tileRect);
				tileVertices.appendUV(uvX, uvY, uvWidth, uvHeight);
				tileVertices.appendAttributes(alpha, colorTransform);
			}
		}

		group.__dirty = false;
		Matrix.__pool.release(tileTransform);
	}

	private static function flush(tilemap:Tilemap, renderer:OpenGLRenderer, blendMode:BlendMode):Void
	{
		if (currentShader == null)
		{
			currentShader = renderer.__defaultDisplayShader;
		}

		if (bufferPosition > lastFlushedPosition && currentBitmapData != null && currentShader != null)
		{
			var shader = renderer.__initDisplayShader(cast currentShader);
			renderer.setShader(shader);
			renderer.applyBitmapData(currentBitmapData, tilemap.smoothing);
			renderer.__applyTransformMatrix(tilemap.__renderTransform, AUTO);

			if (tilemap.tileAlphaEnabled)
			{
				renderer.useAlphaArray();
			}
			else
			{
				renderer.applyAlpha(tilemap.__worldAlpha);
			}

			if (tilemap.tileBlendModeEnabled)
			{
				renderer.__setBlendMode(blendMode);
			}

			if (tilemap.tileColorTransformEnabled)
			{
				renderer.applyHasColorTransform(true);
				renderer.useColorTransformArray();
			}
			else
			{
				renderer.applyColorTransform(tilemap.__worldColorTransform);
			}

			renderer.updateShader();

			var vertexBuffer = tilemap.__buffer.vertexBuffer;
			var vertexBufferPosition = lastFlushedPosition * dataPerVertex * 4;
			var length = (bufferPosition - lastFlushedPosition);

			while (lastFlushedPosition < bufferPosition)
			{
				length = Std.int(Math.min(bufferPosition - lastFlushedPosition, context.__quadIndexBufferElements));
				if (length <= 0) break;

				if (shader.__position != null)
				{
					context.setVertexBufferAt(shader.__position.index, vertexBuffer, vertexBufferPosition, FLOAT_2);
				}

				if (shader.__textureCoord != null)
				{
					context.setVertexBufferAt(shader.__textureCoord.index, vertexBuffer, vertexBufferPosition + 2, FLOAT_2);
				}

				if (tilemap.tileAlphaEnabled)
				{
					if (shader.__alpha != null)
					{
						context.setVertexBufferAt(shader.__alpha.index, vertexBuffer, vertexBufferPosition + 4, FLOAT_1);
					}
				}

				if (tilemap.tileColorTransformEnabled)
				{
					var position = tilemap.tileAlphaEnabled ? 5 : 4;
					if (shader.__colorMultiplier != null)
					{
						context.setVertexBufferAt(shader.__colorMultiplier.index, vertexBuffer, vertexBufferPosition + position, FLOAT_4);
					}
					if (shader.__colorOffset != null)
					{
						context.setVertexBufferAt(shader.__colorOffset.index, vertexBuffer, vertexBufferPosition + position + 4, FLOAT_4);
					}
				}

				context.drawTriangles(context.__quadIndexBuffer, 0, length * 2);
				lastFlushedPosition += length;
			}

			#if gl_stats
			Context3DStats.incrementDrawCall(DrawCallContext.STAGE);
			#end

			renderer.__clearShader();
		}

		lastUsedBitmapData = currentBitmapData;
		lastUsedShader = currentShader;
	}

	public static function render(tilemap:Tilemap, renderer:OpenGLRenderer):Void
	{
		if (!tilemap.__renderable || tilemap.__worldAlpha <= 0) return;

		context = renderer.__context3D;

		buildBuffer(tilemap, renderer);

		if (numTiles == 0) return;

		bufferPosition = 0;

		lastFlushedPosition = 0;
		lastUsedBitmapData = null;
		lastUsedShader = null;
		currentBitmapData = null;
		currentShader = null;

		currentBlendMode = tilemap.__worldBlendMode;

		if (!tilemap.tileBlendModeEnabled)
		{
			renderer.__setBlendMode(currentBlendMode);
		}

		renderer.__pushMaskObject(tilemap);
		// renderer.filterManager.pushObject (tilemap);

		var rect = Rectangle.__pool.get();
		rect.setTo(0, 0, tilemap.__width, tilemap.__height);
		renderer.__pushMaskRect(rect, tilemap.__renderTransform);

		renderTileContainer(tilemap, renderer, tilemap.__group, cast tilemap.__worldShader, tilemap.__tileset, tilemap.__worldAlpha,
			tilemap.tileBlendModeEnabled, currentBlendMode, null);
		flush(tilemap, renderer, currentBlendMode);

		// renderer.filterManager.popObject (tilemap);
		renderer.__popMaskRect();
		renderer.__popMaskObject(tilemap);

		Rectangle.__pool.release(rect);
	}

	public static function renderDrawable(tilemap:Tilemap, renderer:OpenGLRenderer):Void
	{
		renderer.__updateCacheBitmap(tilemap, false);

		if (tilemap.__cacheBitmap != null && !tilemap.__isCacheBitmapRender)
		{
			Context3DBitmap.render(tilemap.__cacheBitmap, renderer);
		}
		else
		{
			Context3DDisplayObject.render(tilemap, renderer);
			Context3DTilemap.render(tilemap, renderer);
		}

		renderer.__renderEvent(tilemap);
	}

	public static function renderDrawableMask(tilemap:Tilemap, renderer:OpenGLRenderer):Void
	{
		// renderer.__updateCacheBitmap(tilemap, false);

		// if (tilemap.__cacheBitmap != null && !tilemap.__isCacheBitmapRender) {

		// 	Context3DBitmap.renderMask (tilemap.__cacheBitmap, renderer);

		// } else {

		Context3DDisplayObject.renderMask(tilemap, renderer);
		Context3DTilemap.renderMask(tilemap, renderer);

		// }
	}

	private static function renderTileContainer(tilemap:Tilemap, renderer:OpenGLRenderer, group:TileContainer, defaultShader:Shader, defaultTileset:Tileset,
			worldAlpha:Float, blendModeEnabled:Bool, defaultBlendMode:BlendMode, cacheBitmapData:BitmapData):Void
	{
		var tiles = group.__tiles;

		var tileset:Tileset;
		var alpha:Float;
		var visible:Bool;
		var blendMode:BlendMode = null;
		var id:Int;
		var tileData:TileData;
		var tileRect:Rectangle;
		var shader:Shader;
		var bitmapData:BitmapData;

		for (tile in tiles)
		{
			tileset = tile.tileset != null ? tile.tileset : defaultTileset;

			alpha = tile.alpha * worldAlpha;
			visible = tile.visible;
			if (!visible || alpha <= 0) continue;

			shader = tile.shader != null ? tile.shader : defaultShader;

			if (blendModeEnabled)
			{
				blendMode = (tile.__blendMode != null) ? tile.__blendMode : defaultBlendMode;
			}

			if (tile.__length > 0)
			{
				renderTileContainer(tilemap, renderer, cast tile, shader, tileset, alpha, blendModeEnabled, blendMode, cacheBitmapData);
			}
			else
			{
				if (tileset == null) continue;

				id = tile.id;

				bitmapData = tileset.__bitmapData;
				if (bitmapData == null) continue;

				if (id == -1)
				{
					tileRect = tile.__rect;
					if (tileRect == null || tileRect.width <= 0 || tileRect.height <= 0) continue;
				}
				else
				{
					tileData = tileset.__data[id];
					if (tileData == null) continue;
				}

				var numBuffer:Int = bufferPosition - lastFlushedPosition;
				var forceFlush:Bool = numBuffer >= 16383;

				if ((forceFlush)
					|| (shader != currentShader)
					|| (bitmapData != currentBitmapData && currentBitmapData != null)
					|| (currentBlendMode != blendMode))
				{
					flush(tilemap, renderer, currentBlendMode);
				}

				currentBitmapData = bitmapData;
				currentShader = shader;
				currentBlendMode = blendMode;
				bufferPosition++;
			}
		}
	}

	public static function renderMask(tilemap:Tilemap, renderer:OpenGLRenderer):Void
	{
		// tilemap.__updateTileArray ();

		// if (tilemap.__tileArray == null || tilemap.__tileArray.length == 0) return;

		// var renderer:OpenGLRenderer = cast renderer.renderer;
		// var gl = renderer.__gl;

		// var shader = renderer.__maskShader;

		// var uMatrix = renderer.__getMatrix (tilemap.__renderTransform);
		// var smoothing = (renderer.__allowSmoothing && tilemap.smoothing);

		// var tileArray = tilemap.__tileArray;
		// var defaultTileset = tilemap.__tileset;

		// tileArray.__updateGLBuffer (gl, defaultTileset, tilemap.__worldAlpha, tilemap.__worldColorTransform);

		// gl.vertexAttribPointer (shader.openfl_Position.index, 2, gl.FLOAT, false, 25 * Float32Array.BYTES_PER_ELEMENT, 0);
		// gl.vertexAttribPointer (shader.openfl_TextureCoord.index, 2, gl.FLOAT, false, 25 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);

		// var cacheBitmapData:BitmapData = null;
		// var lastIndex = 0;
		// var skipped = tileArray.__bufferSkipped;
		// var drawCount = tileArray.__length;

		// tileArray.position = 0;

		// var tileset, flush = false;

		// for (i in 0...(drawCount + 1)) {

		// 	if (skipped[i]) {

		// 		continue;

		// 	}

		// 	tileArray.position = (i < drawCount ? i : drawCount - 1);

		// 	tileset = tileArray.tileset;
		// 	if (tileset == null) tileset = defaultTileset;
		// 	if (tileset == null) continue;

		// 	if (tileset.__bitmapData != cacheBitmapData && cacheBitmapData != null) {

		// 		flush = true;

		// 	}

		// 	if (flush) {

		// 		shader.openfl_Texture.input = cacheBitmapData;
		// 		renderer.shaderManager.updateShader ();

		// 		gl.drawArrays (gl.TRIANGLES, lastIndex * 6, (i - lastIndex) * 6);

		// 		#if gl_stats
		// 			Context3DStats.incrementDrawCall (DrawCallContext.STAGE);
		// 		#end

		// 		flush = false;
		// 		lastIndex = i;

		// 	}

		// 	cacheBitmapData = tileset.__bitmapData;

		// 	if (i == drawCount && tileset.__bitmapData != null) {

		// 		shader.openfl_Texture.input = tileset.__bitmapData;
		// 		renderer.shaderManager.updateShader ();
		// 		gl.drawArrays (gl.TRIANGLES, lastIndex * 6, (i - lastIndex) * 6);

		// 		#if gl_stats
		// 			Context3DStats.incrementDrawCall (DrawCallContext.STAGE);
		// 		#end

		// 	}

		// }
	}

	private static function resizeBuffer(tilemap:Tilemap, count:Int):Void
	{
		if (tilemap.__buffer == null)
		{
			tilemap.__buffer = new Context3DBuffer(context, QUADS, count, dataPerVertex);
		}
		else
		{
			tilemap.__buffer.resize(count, dataPerVertex);
		}
	}
}
#end
