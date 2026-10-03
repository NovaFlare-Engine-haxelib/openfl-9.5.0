# NovaFlare compatibility

Adds CNE/Origin shader inspection/source options, enum values, texture and bitmap APIs, drawing depth-state commands, window dragging, selection colors, and utility/XML types while keeping NF's rendering pipeline.

Origin extra Graphics buffers are an explicit fallback: addBuffer allocates an ID; setBufferFilters does nothing and getBuffer returns null. GraphicsTessellator.prepare returns false so the existing graphics renderer remains responsible for drawing. DeviceRotation reports unsupported; it accepts ordinary EventDispatcher listeners. Complex blend constants are available, but complex blend equations and array-uniform upload are not added to NF's renderer.

Legacy Context3DTextureFormat numeric values are retained; new RGB/RGBA values have distinct IDs. Standalone users must use the shader/texture enums symbolically rather than donor-specific numeric IDs.

The Lime include.xml installs an idempotent build macro for projects that override the original Shader/FlxRuntimeShader source files. It supplies only missing compatibility fields and preserves existing implementation logic. Direct haxe users with overrides can add the corresponding NFShaderCompat/NFRuntimeShaderCompat build metadata explicitly.

Upstream licenses and contributor notices are preserved.
