package openfl.display._internal;

#if (cpp && lime && lime_cffi && !disable_cffi && !macro && (lime_opengl || lime_opengles) && !flash)
import openfl.Vector;
import openfl.display.BitmapData;

class Context3DTriangleBatch
{
	public final sourceVertices:Vector<Float>;
	public final sourceIndices:Vector<Int>;
	public final sourceUVT:Vector<Float>;
	public final bitmap:BitmapData;
	public final vertices:Array<Float>;
	public final indices:Array<Int>;
	public final uvtData:Array<Float>;
	public final bitmapWidth:Int;
	public final bitmapHeight:Int;
	public final count:Int;
	public final hasUVT:Bool;

	public function new(vertices:Vector<Float>, indices:Vector<Int>, uvtData:Vector<Float>, bitmap:BitmapData)
	{
		sourceVertices = vertices;
		sourceIndices = indices;
		sourceUVT = uvtData;
		this.bitmap = bitmap;
		this.vertices = untyped (vertices).__array;
		this.indices = indices == null ? null : untyped (indices).__array;
		this.uvtData = uvtData == null ? null : untyped (uvtData).__array;
		bitmapWidth = bitmap != null && uvtData == null ? bitmap.width : 0;
		bitmapHeight = bitmap != null && uvtData == null ? bitmap.height : 0;
		final numVertices = Math.floor(vertices.length / 2);
		count = indices == null ? numVertices : indices.length;
		hasUVT = uvtData != null && uvtData.length >= numVertices * 3;
	}
}
#end
