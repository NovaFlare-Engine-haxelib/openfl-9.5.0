package openfl.utils._internal;
#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
using Lambda;
import haxe.macro.ExprTools;
/** Supplies the compatibility API when a project retains an older Shader override. */
class NFShaderCompat {
 public static function build():Array<Field> {
  var fields=Context.getBuildFields();
  if (fields.exists(f -> f.name == "__compatSource")) return fields;
  var compatibility = macro class {
	public static function getParameterTypeFromGLEnum(type:Int, isArray:Bool):Null<openfl.display.ShaderParameterType>
	{
		return switch (type)
		{
			case lime.graphics.opengl.GL.BOOL: isArray ? BOOLV : BOOL;
			case lime.graphics.opengl.GL.FLOAT: isArray ? FLOATV : FLOAT;
			case lime.graphics.opengl.GL.INT, lime.graphics.opengl.GL.UNSIGNED_INT: isArray ? INTV : INT;
			case lime.graphics.opengl.GL.BOOL_VEC2: isArray ? BOOL2V : BOOL2;
			case lime.graphics.opengl.GL.BOOL_VEC3: isArray ? BOOL3V : BOOL3;
			case lime.graphics.opengl.GL.BOOL_VEC4: isArray ? BOOL4V : BOOL4;
			case lime.graphics.opengl.GL.INT_VEC2, lime.graphics.opengl.GL.UNSIGNED_INT_VEC2: isArray ? INT2V : INT2;
			case lime.graphics.opengl.GL.INT_VEC3, lime.graphics.opengl.GL.UNSIGNED_INT_VEC3: isArray ? INT3V : INT3;
			case lime.graphics.opengl.GL.INT_VEC4, lime.graphics.opengl.GL.UNSIGNED_INT_VEC4: isArray ? INT4V : INT4;
			case lime.graphics.opengl.GL.FLOAT_VEC2: isArray ? FLOAT2V : FLOAT2;
			case lime.graphics.opengl.GL.FLOAT_VEC3: isArray ? FLOAT3V : FLOAT3;
			case lime.graphics.opengl.GL.FLOAT_VEC4: isArray ? FLOAT4V : FLOAT4;
			case lime.graphics.opengl.GL.FLOAT_MAT2: isArray ? MATRIX2X2V : MATRIX2X2;
			case lime.graphics.opengl.GL.FLOAT_MAT2x3: isArray ? MATRIX2X3V : MATRIX2X3;
			case lime.graphics.opengl.GL.FLOAT_MAT2x4: isArray ? MATRIX2X4V : MATRIX2X4;
			case lime.graphics.opengl.GL.FLOAT_MAT3x2: isArray ? MATRIX3X2V : MATRIX3X2;
			case lime.graphics.opengl.GL.FLOAT_MAT3: isArray ? MATRIX3X3V : MATRIX3X3;
			case lime.graphics.opengl.GL.FLOAT_MAT3x4: isArray ? MATRIX3X4V : MATRIX3X4;
			case lime.graphics.opengl.GL.FLOAT_MAT4x2: isArray ? MATRIX4X2V : MATRIX4X2;
			case lime.graphics.opengl.GL.FLOAT_MAT4x3: isArray ? MATRIX4X3V : MATRIX4X3;
			case lime.graphics.opengl.GL.FLOAT_MAT4: isArray ? MATRIX4X4V : MATRIX4X4;
			default: null;
		}
	}

	public static function getParameterTypeFromGLSL(string:String, isArray:Bool):Null<openfl.display.ShaderParameterType>
	{
		return switch (string)
		{
			case "bool": isArray ? BOOLV : BOOL;
			case "double", "float": isArray ? FLOATV : FLOAT;
			case "int", "uint": isArray ? INTV : INT;
			case "bvec2": isArray ? BOOL2V : BOOL2;
			case "bvec3": isArray ? BOOL3V : BOOL3;
			case "bvec4": isArray ? BOOL4V : BOOL4;
			case "ivec2", "uvec2": isArray ? INT2V : INT2;
			case "ivec3", "uvec3": isArray ? INT3V : INT3;
			case "ivec4", "uvec4": isArray ? INT4V : INT4;
			case "vec2", "dvec2": isArray ? FLOAT2V : FLOAT2;
			case "vec3", "dvec3": isArray ? FLOAT3V : FLOAT3;
			case "vec4", "dvec4": isArray ? FLOAT4V : FLOAT4;
			case "mat2", "mat2x2": isArray ? MATRIX2X2V : MATRIX2X2;
			case "mat2x3": isArray ? MATRIX2X3V : MATRIX2X3;
			case "mat2x4": isArray ? MATRIX2X4V : MATRIX2X4;
			case "mat3x2": isArray ? MATRIX3X2V : MATRIX3X2;
			case "mat3", "mat3x3": isArray ? MATRIX3X3V : MATRIX3X3;
			case "mat3x4": isArray ? MATRIX3X4V : MATRIX3X4;
			case "mat4x2": isArray ? MATRIX4X2V : MATRIX4X2;
			case "mat4x3": isArray ? MATRIX4X3V : MATRIX4X3;
			case "mat4", "mat4x4": isArray ? MATRIX4X4V : MATRIX4X4;
			default: null;
		}
	}

	public static function processGLSLParameter(source:String, storageType:String, callback:Bool->String->String->Int->Null<String>->Void):String
	{
		var isVertex = storageType != "uniform", regex:EReg = switch (storageType)
		{
			case "uniform": ~/\buniform\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?\s*(?:=)?\s*(.+?(?=;))?/gu;
			case "in": ~/\bin\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
			case "attribute": ~/\battribute\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
			default: throw "Unknown storageType for Shader.processGLSLParameter " + storageType;
		}

		var arrayLength:Null<Int>, position;
		return regex.map(source, (_) ->
		{
			if (regex.matched(3) == null) arrayLength = 0;
			else if ((arrayLength = Std.parseInt(regex.matched(3))) == null) arrayLength = 1;

			callback(isVertex, regex.matched(1), regex.matched(2), arrayLength, isVertex ? null : regex.matched(4));

			if (isVertex)
			{
				position = regex.matchedPos();
				return source.substr(position.pos, position.len);
			}
			else
			{
				return 'uniform ${regex.matched(1)} ${regex.matched(2)}${arrayLength == 0 ? "" : "[" + regex.matched(3) + "]"}';
			}
		});
	}

public var glVersion(default,set):Null<String>;
 private function set_glVersion(value:Null<String>):Null<String> { __glSourceDirty = true; return glVersion=value; }
 public var glVersionRaw(get,never):Null<String>;
 private function get_glVersionRaw():Null<String> return glVersion;
 public var glVertexExtensions(default,set):Map<String,String> = new Map();
 public var glFragmentExtensions(default,set):Map<String,String> = new Map();
 public var glVertexPragmas(default,set):Map<String,String> = new Map();
 public var glFragmentPragmas(default,set):Map<String,String> = new Map();
 public var glFragmentHeaderRaw(get,never):String;
 private function get_glFragmentHeaderRaw():String return glFragmentPragmas!=null?glFragmentPragmas.get("header"):null;
 public var glFragmentBodyRaw(get,never):String;
 private function get_glFragmentBodyRaw():String return glFragmentPragmas!=null?glFragmentPragmas.get("body"):null;
 public var glFragmentSourceRaw(get,never):String;
 private function get_glFragmentSourceRaw():String return __glFragmentSource;
 public var glVertexHeaderRaw(get,never):String;
 private function get_glVertexHeaderRaw():String return glVertexPragmas!=null?glVertexPragmas.get("header"):null;
 public var glVertexBodyRaw(get,never):String;
 private function get_glVertexBodyRaw():String return glVertexPragmas!=null?glVertexPragmas.get("body"):null;
 public var glVertexSourceRaw(get,never):String;
 private function get_glVertexSourceRaw():String return __glVertexSource;
 private function __compatSource(source:String,prefix:String,pragmas:Map<String,String>,extensions:Map<String,String>):String {
  if (source==null) return source;
  var version=glVersion;
  var versionRegex=~/^\s*#version[^\n]*(?:\n|$)/;
  if(versionRegex.match(source)) { if(version==null) version=StringTools.trim(versionRegex.matched(0)).substr(9); source=versionRegex.replace(source,""); }
  var head=version==null?"":"#version "+version+"\n";
  if(extensions!=null) for(name=>value in extensions) head+="#extension "+name+" : "+value+"\n";
  head+=prefix;
  if(pragmas!=null) { var header=pragmas.get("header"),body=pragmas.get("body"); if(header!=null) head+=header+"\n"; if(body!=null) source=StringTools.replace(source,"#pragma body",body); }
  return head+source;
 }
private function set_glVertexExtensions(value:Map<String,String>):Map<String,String> { __glSourceDirty=true; return glVertexExtensions=value; }
private function set_glFragmentExtensions(value:Map<String,String>):Map<String,String> { __glSourceDirty=true; return glFragmentExtensions=value; }
private function set_glVertexPragmas(value:Map<String,String>):Map<String,String> { __glSourceDirty=true; return glVertexPragmas=value; }
private function set_glFragmentPragmas(value:Map<String,String>):Map<String,String> { __glSourceDirty=true; return glFragmentPragmas=value; }
  };
  for (field in compatibility.fields) if (!fields.exists(f -> f.name == field.name)) fields.push(field);
  // Preserve NF's compile cache, error handling and mobile conversion. Only assemble source headers.
  function rewrite(expr:Expr):Expr {
   switch (expr.expr) {
    case EBinop(OpAdd, {expr:EConst(CIdent("prefix"))}, {expr:EConst(CIdent(source))})
      if (source == "glVertexSource" || source == "glFragmentSource"):
     var stage=source == "glVertexSource" ? "glVertex" : "glFragment";
     return Context.parse('__compatSource('+source+', prefix, '+stage+'Pragmas, '+stage+'Extensions)', expr.pos);
    default: return ExprTools.map(expr,rewrite);
   }
  }
  for (field in fields) if (field.name == "__initGL") switch (field.kind) {
   case FFun(fn): if (fn.expr != null) fn.expr=rewrite(fn.expr);
   default:
  }
  return fields;
 }
}
#end
