package openfl.display._internal;

#if !flash
import openfl.display3D._internal.GLBuffer;
import openfl.display3D.Context3D;
import openfl.utils._internal.Float32Array;
import openfl.display3D.Context3DMipFilter;
import openfl.display3D.Context3DTextureFilter;
import openfl.display3D.Context3DWrapMode;
import openfl.display.BitmapData;
import openfl.display.GraphicsShader;
import openfl.display.ShaderInput;
import openfl.display.ShaderParameter;

#if (cpp && lime && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
import lime._internal.backend.native.NativeCFFI;

private typedef ShaderAttributeSegment = {
	var offset:Int;
	var values:Array<Float>;
	var repeat:Int;
	var components:Int;
}
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display.Shader)
@:access(openfl.display.ShaderParameter)
@:access(openfl.display3D.Context3D)
@SuppressWarnings("checkstyle:FieldDocComment")
class ShaderBuffer
{
	public var inputCount:Int;
	public var inputRefs:Array<ShaderInput<BitmapData>>;
	public var inputFilter:Array<Context3DTextureFilter>;
	public var inputMipFilter:Array<Context3DMipFilter>;
	public var inputs:Array<BitmapData>;
	public var inputWrap:Array<Context3DWrapMode>;
	public var overrideBoolCount:Int;
	public var overrideBoolNames:Array<String>;
	public var overrideBoolValues:Array<Array<Bool>>;
	// public var overrideCount:Int;
	public var overrideFloatCount:Int;
	public var overrideFloatNames:Array<String>;
	public var overrideFloatValues:Array<Array<Float>>;
	public var overrideIntCount:Int;
	public var overrideIntNames:Array<String>;
	@SuppressWarnings("checkstyle:Dynamic") public var overrideIntValues:Array<Array<Dynamic>>;
	// public var overrideNames:Array<String>;
	// public var overrideValues:Array<Array<Dynamic>>;
	public var paramBoolCount:Int;
	public var paramCount:Int;
	public var paramData:Float32Array;
	public var paramDataBuffer:GLBuffer;
	public var paramDataLength:Int;
	public var paramFloatCount:Int;
	public var paramIntCount:Int;
	public var paramLengths:Array<Int>;
	public var paramPositions:Array<Int>;
	public var paramRefs_Bool:Array<ShaderParameter<Bool>>;
	public var paramRefs_Float:Array<ShaderParameter<Float>>;
	public var paramRefs_Int:Array<ShaderParameter<Int>>;
	public var paramTypes:Array<Int>;
	public var shader:GraphicsShader;
	#if (cpp && lime && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
	private static inline var QUAD_VERTEX_COUNT = 4;
	private var shaderParamTicket:Dynamic;
	private var shaderParamCaptureActive:Bool = false;
	private var shaderAttributeSlots:Array<ShaderAttributeSegment>;
	private var deferredAttributes:Array<ShaderAttributeSegment>;
	#end

	public function new()
	{
		inputRefs = [];
		inputFilter = [];
		inputMipFilter = [];
		inputs = [];
		inputWrap = [];
		// overrideNames = [];
		// overrideValues = [];
		overrideIntNames = [];
		overrideIntValues = [];
		overrideFloatNames = [];
		overrideFloatValues = [];
		overrideBoolNames = [];
		overrideBoolValues = [];
		paramLengths = [];
		paramPositions = [];
		paramRefs_Bool = [];
		paramRefs_Float = [];
		paramRefs_Int = [];
		paramTypes = [];
	}

	public function addBoolOverride(name:String, values:Array<Bool>):Void
	{
		overrideBoolNames[overrideBoolCount] = name;
		overrideBoolValues[overrideBoolCount] = values;
		overrideBoolCount++;
	}

	public function addFloatOverride(name:String, values:Array<Float>):Void
	{
		overrideFloatNames[overrideFloatCount] = name;
		overrideFloatValues[overrideFloatCount] = values;
		overrideFloatCount++;
	}

	public function addIntOverride(name:String, values:Array<Int>):Void
	{
		overrideIntNames[overrideIntCount] = name;
		overrideIntValues[overrideIntCount] = values;
		overrideIntCount++;
	}

	public function clearOverride():Void
	{
		// overrideCount = 0;
		overrideIntCount = 0;
		overrideFloatCount = 0;
		overrideBoolCount = 0;
	}

	@:noCompletion public function bindAndUpload(context:Context3D, uploadPrefix:Bool = false):Void
	{
		if (paramDataLength == 0)
		{
			context.__bindGLArrayBuffer(null);
			return;
		}

		final gl = context.gl;
		if (paramDataBuffer == null)
			paramDataBuffer = gl.createBuffer();
		context.__bindGLArrayBuffer(paramDataBuffer);

		#if (cpp && lime && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
		if (shaderParamCaptureActive)
		{
			if (NativeCFFI.tryQueueShaderParams(shaderParamTicket, gl.DYNAMIC_DRAW)) return;

			final dataView:lime.utils.ArrayBufferView = paramData;
			if (!NativeCFFI.materializeShaderParams(shaderParamTicket, dataView.buffer, dataView.byteOffset, paramDataLength))
				throw new haxe.Exception("Could not restore shader attribute data");
			shaderParamCaptureActive = false;
		}
		#end

		if (uploadPrefix)
		{
			#if (lime && sys && lime_cffi && (lime_opengl || lime_opengles) && !doc_gen)
			final dataView:lime.utils.ArrayBufferView = paramData;
			context.__context.gles2.bufferData(gl.ARRAY_BUFFER, paramDataLength * Float32Array.BYTES_PER_ELEMENT, dataView, gl.DYNAMIC_DRAW);
			return;
			#elseif lime
			final data = paramData.length != paramDataLength ? paramData.subarray(0, paramDataLength) : paramData;
			gl.bufferData(gl.ARRAY_BUFFER, data, gl.DYNAMIC_DRAW);
			return;
			#end
		}
		gl.bufferData(gl.ARRAY_BUFFER, paramData, gl.DYNAMIC_DRAW);
	}

	public function update(shader:GraphicsShader, ?compactAlphas:Array<Float>, ?compactMultipliers:Array<Float>, ?compactOffsets:Array<Float>):Bool
	{
		#if lime
		#if (cpp && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
		shaderParamCaptureActive = false;
		#end
		inputCount = 0;
		// overrideCount = 0;
		overrideIntCount = 0;
		overrideFloatCount = 0;
		overrideBoolCount = 0;
		paramBoolCount = 0;
		paramCount = 0;
		paramDataLength = 0;
		paramFloatCount = 0;
		paramIntCount = 0;
		this.shader = null;

		if (shader == null)
		{
			#if (cpp && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
			shaderParamTicket = null;
			#end
			return false;
		}

		shader.__init();
		#if (cpp && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
		if (compactAlphas != null && (!NativeCFFI.supportsShaderAttributeRepetition()
			|| !validateCompactQuadAttributes(shader, compactAlphas, compactMultipliers, compactOffsets))) return false;
		#else
		if (compactAlphas != null) return false;
		#end

		inputCount = shader.__inputBitmapData.length;
		var input:ShaderInput<BitmapData>;

		for (i in 0...inputCount)
		{
			input = shader.__inputBitmapData[i];
			inputs[i] = input.input;
			inputFilter[i] = input.filter;
			inputMipFilter[i] = input.mipFilter;
			inputRefs[i] = input;
			inputWrap[i] = input.wrap;
		}

		var boolCount = shader.__paramBool.length;
		var floatCount = shader.__paramFloat.length;
		var intCount = shader.__paramInt.length;
		paramCount = boolCount + floatCount + intCount;
		paramBoolCount = boolCount;
		paramFloatCount = floatCount;
		paramIntCount = intCount;

		var length = 0, p = 0;
		var param:ShaderParameter<Bool>;

		for (i in 0...boolCount)
		{
			param = shader.__paramBool[i];

			paramPositions[p] = paramDataLength;
			length = (param.value != null ? param.value.length : 0);
			paramLengths[p] = length;
			paramDataLength += length;
			paramTypes[p] = 0;

			paramRefs_Bool[i] = param;
			p++;
		}

		var param:ShaderParameter<Float>;

		for (i in 0...floatCount)
		{
			param = shader.__paramFloat[i];

			paramPositions[p] = paramDataLength;
			length = (param.value != null ? param.value.length : 0);
			#if (cpp && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
			if (compactAlphas != null)
			{
				switch (param.name)
				{
					case "alpha": length = compactAlphas.length * QUAD_VERTEX_COUNT;
					case "colorMultiplier": length = compactMultipliers == null ? 0 : compactMultipliers.length * QUAD_VERTEX_COUNT;
					case "colorOffset": length = compactOffsets == null ? 0 : compactOffsets.length * QUAD_VERTEX_COUNT;
					default:
				}
			}
			#end
			paramLengths[p] = length;
			paramDataLength += length;
			paramTypes[p] = 1;

			paramRefs_Float[i] = param;
			p++;
		}

		var param:ShaderParameter<Int>;

		for (i in 0...intCount)
		{
			param = shader.__paramInt[i];

			paramPositions[p] = paramDataLength;
			length = (param.value != null ? param.value.length : 0);
			paramLengths[p] = length;
			paramDataLength += length;
			paramTypes[p] = 2;

			paramRefs_Int[i] = param;
			p++;
		}

		if (paramDataLength > 0 && (paramData == null || paramDataLength > paramData.length))
			paramData = new Float32Array(paramDataLength);

		var boolIndex = 0;
		var floatIndex = 0;
		var intIndex = 0;

		var paramPosition:Int = 0;
		var boolParam:ShaderParameter<Bool>;
		var floatParam:ShaderParameter<Float>;
		var intParam:ShaderParameter<Int>;
		var length:Int;

		for (i in 0...paramCount)
		{
			length = paramLengths[i];

			if (i < boolCount)
			{
				boolParam = paramRefs_Bool[boolIndex];
				boolIndex++;

				for (j in 0...length)
				{
					paramData[paramPosition] = boolParam.value[j] ? 1 : 0;
					paramPosition++;
				}
			}
			else if (i < boolCount + floatCount)
			{
				floatParam = paramRefs_Float[floatIndex];
				floatIndex++;

				#if (cpp && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
				if (compactAlphas != null && length > 0)
				{
					final values = switch (floatParam.name)
					{
						case "alpha": compactAlphas;
						case "colorMultiplier": compactMultipliers;
						case "colorOffset": compactOffsets;
						default: null;
					}
					if (values != null)
					{
						deferShaderAttribute(paramPosition, values, QUAD_VERTEX_COUNT, floatParam.__length);
						paramPosition += length;
						continue;
					}
				}
				// Uniforms and constant attributes are still read from the CPU array.
				if (!floatParam.__isUniform && length > floatParam.__length)
				{
					deferShaderAttribute(paramPosition, floatParam.value);
					paramPosition += length;
					continue;
				}
				#end
				for (j in 0...length)
				{
					paramData[paramPosition] = floatParam.value[j];
					paramPosition++;
				}
			}
			else
			{
				intParam = paramRefs_Int[intIndex];
				intIndex++;

				for (j in 0...length)
				{
					paramData[paramPosition] = intParam.value[j];
					paramPosition++;
				}
			}
		}

		#if (cpp && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
		finishShaderAttributeCapture();
		#end

		this.shader = shader;
		return true;
		#else
		return false;
		#end
	}

	#if (cpp && lime && lime_cffi && !disable_cffi && !optional_cffi && !lime_webgl && !macro && (lime_opengl || lime_opengles))
	private static function validateCompactQuadAttributes(shader:GraphicsShader, alphas:Array<Float>, multipliers:Array<Float>, offsets:Array<Float>):Bool
	{
		if (alphas.length == 0 || alphas.length > 0x7FFFFFFF / (9 * QUAD_VERTEX_COUNT * Float32Array.BYTES_PER_ELEMENT)) return false;
		if ((multipliers == null) != (offsets == null)) return false;
		if (multipliers != null && (multipliers.length != alphas.length * 4 || offsets.length != multipliers.length)) return false;

		var hasAlpha = false;
		var hasMultiplier = false;
		var hasOffset = false;
		for (parameter in shader.__paramFloat)
		{
			switch (parameter.name)
			{
				case "alpha":
					if (hasAlpha || parameter.__isUniform || parameter.type != FLOAT) return false;
					hasAlpha = true;
				case "colorMultiplier":
					if (hasMultiplier || parameter.__isUniform || parameter.type != FLOAT4) return false;
					hasMultiplier = true;
				case "colorOffset":
					if (hasOffset || parameter.__isUniform || parameter.type != FLOAT4) return false;
					hasOffset = true;
				default:
			}
		}
		return hasAlpha && (multipliers == null || (hasMultiplier && hasOffset));
	}

	private function deferShaderAttribute(offset:Int, values:Array<Float>, repeat:Int = 1, components:Int = 1):Void
	{
		if (deferredAttributes == null)
		{
			deferredAttributes = [];
			shaderAttributeSlots = [];
		}

		final index = deferredAttributes.length;
		if (index == shaderAttributeSlots.length)
			shaderAttributeSlots.push({offset: offset, values: values, repeat: repeat, components: components});
		else
		{
			final segment = shaderAttributeSlots[index];
			segment.offset = offset;
			segment.values = values;
			segment.repeat = repeat;
			segment.components = components;
		}
		deferredAttributes.push(shaderAttributeSlots[index]);
	}

	private function finishShaderAttributeCapture():Void
	{
		if (deferredAttributes == null || deferredAttributes.length == 0)
		{
			shaderParamTicket = null;
			return;
		}

		final view:lime.utils.ArrayBufferView = paramData;
		if (shaderParamTicket == null || !NativeCFFI.tryRecaptureShaderParams(shaderParamTicket, deferredAttributes, view, paramDataLength))
		{
			shaderParamTicket = NativeCFFI.trySnapshotShaderParams(deferredAttributes, view.buffer, view.byteOffset, paramDataLength);
		}
		shaderParamCaptureActive = shaderParamTicket != null;

		for (segment in deferredAttributes)
		{
			if (!shaderParamCaptureActive) materializeDeferredAttribute(segment);
			segment.values = null;
		}
		deferredAttributes.resize(0);
	}

	private function materializeDeferredAttribute(segment:ShaderAttributeSegment):Void
	{
		final values = segment.values;
		if (segment.repeat == 1)
		{
			for (index in 0...values.length)
				paramData[segment.offset + index] = values[index];
			return;
		}

		var position = segment.offset;
		for (attribute in 0...Std.int(values.length / segment.components))
		{
			final source = attribute * segment.components;
			for (copy in 0...segment.repeat)
			{
				for (component in 0...segment.components)
					paramData[position++] = values[source + component];
			}
		}
	}
	#end
}
#end
