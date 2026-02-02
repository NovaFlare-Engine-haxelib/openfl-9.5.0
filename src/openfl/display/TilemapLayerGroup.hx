package openfl.display;

import openfl.display.BlendMode;
import openfl.display.Sprite;
import openfl.display.Tilemap;
import openfl.display.Tileset;

/**
	TilemapLayerGroup 是一种高性能的 Tilemap 管理容器，它实现了“方案 1：手动分层渲染”模式。
	
	它内部为每种使用的 BlendMode 维护一个独立的 Tilemap 层。这样可以确保：
	1. 每层内部的批处理（Batching）绝不会因为混合模式切换而断开。
	2. 自动关闭了 Tile 级别的 blendMode 检查，消除了 CPU 属性读取开销。
	3. 开发者只需要根据物体的性质将其放入对应的层即可。
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class TilemapLayerGroup extends Sprite
{
	private var __layers:Map<BlendMode, Tilemap>;
	private var __tileset:Tileset;
	private var __smoothing:Bool;

	/**
		创建一个新的 TilemapLayerGroup。
		@param	tileset	该组默认使用的 Tileset。
		@param	smoothing	是否启用平滑。
	**/
	public function new(tileset:Tileset = null, smoothing:Bool = true)
	{
		super();
		__layers = new Map();
		__tileset = tileset;
		__smoothing = smoothing;
	}

	/**
		获取指定混合模式的渲染层。如果该层不存在，将自动创建。
		@param	blendMode	需要的混合模式（如 NORMAL, ADD, MULTIPLY 等）。
		@return	对应的 Tilemap 实例。
	**/
	public function getLayer(blendMode:BlendMode = null):Tilemap
	{
		if (blendMode == null) blendMode = NORMAL;

		if (!__layers.exists(blendMode))
		{
			var layer = new Tilemap(stage != null ? stage.stageWidth : 0, stage != null ? stage.stageHeight : 0, __tileset, __smoothing);
			layer.blendMode = blendMode;
			
			// 核心优化：关闭 Tile 级别的混合检查，因为整层都使用相同的混合模式
			layer.tileBlendModeEnabled = false;
			
			__layers.set(blendMode, layer);
			
			// 按照 BlendMode 的常见层级添加（可以根据需要调整添加顺序）
			if (blendMode == NORMAL)
			{
				addChildAt(layer, 0); // 普通层通常在最下面
			}
			else
			{
				addChild(layer); // 特效层（如 ADD）通常在上面
			}
		}

		return __layers.get(blendMode);
	}

	/**
		将一个 Tile 添加到指定混合模式的层中。
		@param	tile	要添加的 Tile。
		@param	blendMode	该 Tile 使用的混合模式。
	**/
	public function addTileToLayer(tile:Tile, blendMode:BlendMode = null):Void
	{
		getLayer(blendMode).addTile(tile);
	}

	/**
		清理所有层。
	**/
	public function clearLayers():Void
	{
		for (layer in __layers)
		{
			layer.removeTiles();
		}
	}

	// Getters & Setters
	private function get_tileset():Tileset { return __tileset; }
	private function set_tileset(value:Tileset):Tileset 
	{
		__tileset = value;
		for (layer in __layers) layer.tileset = value;
		return value;
	}
}
