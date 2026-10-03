package openfl.display._internal;
@:access(openfl.display.Graphics)
class GraphicsTessellator {
 public static function prepare(graphics:openfl.display.Graphics):Bool return false;
 public static function commandsContainGradient(graphics:openfl.display.Graphics):Bool {
  if(graphics==null) return false;
  for(type in graphics.__commands.types) switch(type) {case BEGIN_GRADIENT_FILL,LINE_GRADIENT_STYLE:return true;default:}
  return false;
 }
}
