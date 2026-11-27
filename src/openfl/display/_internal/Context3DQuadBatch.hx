package openfl.display._internal;

#if !flash
import openfl.Vector;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.utils._internal.Float32Array;

private typedef QuadInput<T> = #if cpp Array<T> #else Vector<T> #end;

@:access(openfl.geom.Matrix)
class Context3DQuadBatch
{
	public static inline var VALUES_PER_QUAD = 16;

	public final rects:QuadInput<Float>;
	public final indices:QuadInput<Int>;
	public final transforms:QuadInput<Float>;
	public final bitmapWidth:Int;
	public final bitmapHeight:Int;
	public final count:Int;

	public function new(rects:QuadInput<Float>, indices:QuadInput<Int>, transforms:QuadInput<Float>, bitmap:BitmapData)
	{
		this.rects = rects;
		this.indices = indices;
		this.transforms = transforms;
		bitmapWidth = textureDimension(bitmap == null ? 1 : bitmap.width);
		bitmapHeight = textureDimension(bitmap == null ? 1 : bitmap.height);
		count = indices == null ? Math.floor(rects.length / 4) : indices.length;
	}

	public static function writeVertices(batches:Array<Context3DQuadBatch>, vertices:Float32Array):Void
	{
		// Translation-only batches inherit the linear part of the previous transform.
		final matrix = new Matrix();
		var offset = 0;
		for (batch in batches)
		{
			batch.writeBatch(vertices, offset, matrix);
			offset += batch.count * VALUES_PER_QUAD;
		}
	}

	private function writeBatch(vertices:Float32Array, offset:Int, matrix:Matrix):Void
	{
		final rectCount = Math.floor(rects.length / 4);
		final transformStride = getTransformStride();
		for (quadIndex in 0...count)
		{
			final quadOffset = offset + quadIndex * VALUES_PER_QUAD;
			final rectIndex = indices == null ? quadIndex : indices[quadIndex];
			if (rectIndex < 0 || rectIndex >= rectCount)
			{
				clearQuad(vertices, quadOffset);
				continue;
			}
			final rectOffset = rectIndex * 4;
			if (rects[rectOffset + 2] <= 0 || rects[rectOffset + 3] <= 0)
			{
				clearQuad(vertices, quadOffset);
				continue;
			}

			updateMatrix(matrix, quadIndex, rectOffset, transformStride);
			writeQuad(vertices, quadOffset, matrix, rectOffset);
		}
	}

	private function getTransformStride():Int
	{
		if (transforms == null) return 0;
		if (transforms.length >= count * 6) return 6;
		if (transforms.length >= count * 4) return 4;
		if (transforms.length >= count * 2) return 2;
		return 0;
	}

	private inline function updateMatrix(matrix:Matrix, quadIndex:Int, rectOffset:Int, stride:Int):Void
	{
		final transformOffset = quadIndex * stride;
		if (stride >= 4)
		{
			matrix.a = transforms[transformOffset];
			matrix.b = transforms[transformOffset + 1];
			matrix.c = transforms[transformOffset + 2];
			matrix.d = transforms[transformOffset + 3];
		}
		if (stride == 2 || stride == 6)
		{
			final translationOffset = transformOffset + (stride == 6 ? 4 : 0);
			matrix.tx = transforms[translationOffset];
			matrix.ty = transforms[translationOffset + 1];
		}
		else
		{
			matrix.tx = rects[rectOffset];
			matrix.ty = rects[rectOffset + 1];
		}
	}

	private inline function writeQuad(vertices:Float32Array, offset:Int, matrix:Matrix, rectOffset:Int):Void
	{
		final x = rects[rectOffset];
		final y = rects[rectOffset + 1];
		final width = rects[rectOffset + 2];
		final height = rects[rectOffset + 3];
		final left = x / bitmapWidth;
		final top = y / bitmapHeight;
		final right = (x + width) / bitmapWidth;
		final bottom = (y + height) / bitmapHeight;

		vertices[offset] = matrix.__transformX(0, 0);
		vertices[offset + 1] = matrix.__transformY(0, 0);
		vertices[offset + 2] = left;
		vertices[offset + 3] = top;
		vertices[offset + 4] = matrix.__transformX(width, 0);
		vertices[offset + 5] = matrix.__transformY(width, 0);
		vertices[offset + 6] = right;
		vertices[offset + 7] = top;
		vertices[offset + 8] = matrix.__transformX(0, height);
		vertices[offset + 9] = matrix.__transformY(0, height);
		vertices[offset + 10] = left;
		vertices[offset + 11] = bottom;
		vertices[offset + 12] = matrix.__transformX(width, height);
		vertices[offset + 13] = matrix.__transformY(width, height);
		vertices[offset + 14] = right;
		vertices[offset + 15] = bottom;
	}

	private static inline function clearQuad(vertices:Float32Array, offset:Int):Void
	{
		// An invalid index still occupies a slot in the draw and shader input buffers.
		for (valueIndex in 0...VALUES_PER_QUAD)
			vertices[offset + valueIndex] = 0;
	}

	private static function textureDimension(size:Int):Int
	{
		#if openfl_power_of_two
		var dimension = 1;
		while (dimension < size)
			dimension <<= 1;
		return dimension;
		#else
		return size;
		#end
	}
}
#end
