package openfl.display._internal;

#if !flash
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.utils._internal.Float32Array;

class Context3DTileVertices
{
	private static inline var POSITION_AND_UV_VALUES = 4;
	private static inline var GEOMETRY_VALUES = 12;
	private static inline var COLOR_TRANSFORM_VALUES = 8;
	private static inline var ALPHA_FLAG = 1;
	private static inline var COLOR_TRANSFORM_FLAG = 2;
	private static inline var VERTICES_PER_TILE = 4;

	public final records:Array<Float> = [];
	public var flags(default, null):Int;
	public var stride(default, null):Int;
	public var tileCount(default, null):Int;
	public var alphaEnabled(default, null):Bool;
	public var colorTransformEnabled(default, null):Bool;

	public function new() {}

	public function reset(alphaEnabled:Bool, colorTransformEnabled:Bool):Void
	{
		this.alphaEnabled = alphaEnabled;
		this.colorTransformEnabled = colorTransformEnabled;
		flags = (alphaEnabled ? ALPHA_FLAG : 0) | (colorTransformEnabled ? COLOR_TRANSFORM_FLAG : 0);
		stride = POSITION_AND_UV_VALUES + (alphaEnabled ? 1 : 0) + (colorTransformEnabled ? COLOR_TRANSFORM_VALUES : 0);
		tileCount = 0;
		records.resize(0);
	}

	public inline function appendGeometry(transform:Matrix, rect:Rectangle):Void
	{
		records.push(transform.a);
		records.push(transform.b);
		records.push(transform.c);
		records.push(transform.d);
		records.push(transform.tx);
		records.push(transform.ty);
		records.push(rect.width);
		records.push(rect.height);
	}

	public inline function appendUV(left:Float, top:Float, right:Float, bottom:Float):Void
	{
		records.push(left);
		records.push(top);
		records.push(right);
		records.push(bottom);
	}

	public inline function appendAttributes(alpha:Float, transform:ColorTransform):Void
	{
		if (alphaEnabled) records.push(alpha);
		if (colorTransformEnabled)
		{
			records.push(transform == null ? 1 : transform.redMultiplier);
			records.push(transform == null ? 1 : transform.greenMultiplier);
			records.push(transform == null ? 1 : transform.blueMultiplier);
			records.push(transform == null ? 1 : transform.alphaMultiplier);
			records.push(transform == null ? 0 : transform.redOffset);
			records.push(transform == null ? 0 : transform.greenOffset);
			records.push(transform == null ? 0 : transform.blueOffset);
			records.push(transform == null ? 0 : transform.alphaOffset);
		}
		tileCount++;
	}

	public inline function usedFloats():Int
	{
		return tileCount * stride * VERTICES_PER_TILE;
	}

	public function writeVertices(vertices:Float32Array):Void
	{
		final attributeCount = stride - POSITION_AND_UV_VALUES;
		final recordSize = GEOMETRY_VALUES + attributeCount;
		var record = 0;
		var vertex = 0;
		while (record < records.length)
		{
			final horizontalX = records[record];
			final horizontalY = records[record + 1];
			final verticalX = records[record + 2];
			final verticalY = records[record + 3];
			final originX = records[record + 4];
			final originY = records[record + 5];
			final width = records[record + 6];
			final height = records[record + 7];
			final left = records[record + 8];
			final top = records[record + 9];
			final right = records[record + 10];
			final bottom = records[record + 11];

			for (corner in 0...VERTICES_PER_TILE)
			{
				final useRight = (corner & 1) != 0;
				final useBottom = (corner & 2) != 0;
				final localX = useRight ? width : 0.0;
				final localY = useBottom ? height : 0.0;
				vertices[vertex] = localX * horizontalX + localY * verticalX + originX;
				vertices[vertex + 1] = localX * horizontalY + localY * verticalY + originY;
				vertices[vertex + 2] = useRight ? right : left;
				vertices[vertex + 3] = useBottom ? bottom : top;
				for (attribute in 0...attributeCount)
					vertices[vertex + POSITION_AND_UV_VALUES + attribute] = records[record + GEOMETRY_VALUES + attribute];
				vertex += stride;
			}
			record += recordSize;
		}
	}
}
#end
