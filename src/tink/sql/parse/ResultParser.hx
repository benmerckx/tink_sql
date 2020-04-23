package tink.sql.parse;

import geojson.GeometryCollection;
import tink.sql.Expr;
import haxe.DynamicAccess;
import tink.sql.format.SqlFormatter;
import tink.sql.expr.ExprTyper;
import haxe.io.Bytes;
import haxe.io.BytesInput;

using tink.CoreApi;

class ResultParser<Db> {
  public function new() {}
  
  function parseGeometryValue<T, C>(bytes: Bytes): geojson.util.GeoJson<T, C> {
    var buffer = new BytesInput(bytes, 4);
    function parseGeometry(): geojson.util.GeoJson<Dynamic, Dynamic> {
      inline function multi(): Dynamic
        return [for (_ in 0 ... buffer.readInt32()) parseGeometry()];
      inline function parsePoint(): Array<Float> {
        var y = buffer.readDouble(), x = buffer.readDouble();
        return [x, y];
      }
      inline function coordinates() {
        var point = parsePoint();
        return new geojson.util.Coordinates(point[0], point[1]);
      }
      buffer.bigEndian = buffer.readByte() == 0;
      switch buffer.readInt32() {
        case 1:
          var point = parsePoint();
          return new geojson.Point(point[0], point[1]);
        case 2:
          return new geojson.LineString([
            for (_ in 0 ... buffer.readInt32()) coordinates()
          ]);
        case 3:
          return new geojson.Polygon([for (_ in 0 ... buffer.readInt32())
            [for (_ in 0 ... buffer.readInt32()) coordinates()]
          ]);
        case 4: return new geojson.MultiPoint(multi());
        case 5: return new geojson.MultiLineString(multi());
        case 6: return geojson.MultiPolygon.fromPolygons(multi());
        case 7: return (new geojson.GeometryCollection(multi()): Dynamic);
        case v: throw 'GeoJson type $v not supported';
      }
    } 
    return parseGeometry(); 
  }

  function parseValue(value:Dynamic, type:Option<ExprType<Dynamic>>): Any {
    if (value == null) return null;
    return switch type {
      case Some(ExprType.VBool) if (Std.is(value, String)): 
        value == '1';
      case Some(ExprType.VBool) if (Std.is(value, Int)): 
        value > 0;
      case Some(ExprType.VBool): !!value;
      case Some(ExprType.VString):
        '${value}';
      case Some(ExprType.VFloat) if (Std.is(value, String)):
        Std.parseFloat(value);
      case Some(ExprType.VInt) if (Std.is(value, String)):
        Std.parseInt(value);
      case Some(ExprType.VDate) if (Std.is(value, String)):
        Date.fromString(value);
      case Some(ExprType.VDate) if (Std.is(value, Float)):
        Date.fromTime(value);
      #if js 
      case Some(ExprType.VBytes) if (Std.is(value, js.node.Buffer)):
        (value: js.node.Buffer).hxToBytes();
      #end
      case Some(ExprType.VBytes) if (Std.is(value, String)):
        haxe.io.Bytes.ofString(value);
      case Some(ExprType.VGeometry(_)):
        if (Std.is(value, String)) parseGeometryValue(Bytes.ofString(value))
        else if (Std.is(value, Bytes)) parseGeometryValue(value)
        else value;
      default: value;
    }
  }

  public function queryParser<Row:{}>(
    query:Query<Db, Dynamic>,
    nest:Bool
  ): DynamicAccess<Any> -> Row {
    var types = ExprTyper.typeQuery(query);
    return function (row: DynamicAccess<Any>) {
      var res: DynamicAccess<Any> = {}
      var target = res;
      for (field in row.keys()) {
        var name = field;
        var table = null;
        if (nest) {
          var parts = field.split(SqlFormatter.FIELD_DELIMITER);
          table = parts[0];
          name = parts[1];
          target =
            if (!res.exists(table)) res[table] = {};
            else res[table];
        }
        target[name] = parseValue(row[field], 
          switch types.get(field) {
            case null: None;
            case v: v;
          }
        );
      }
      return cast res;
    }
  }
}