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

  function parseValue(value:Dynamic, type:ExprType<Dynamic>): Any {
    if (value == null) return null;
    return switch type {
      case null: value;
      case ExprType.VBool if (Std.is(value, String)): 
        value == '1';
      case ExprType.VBool if (Std.is(value, Int)): 
        value > 0;
      case ExprType.VBool: !!value;
      case ExprType.VString:
        '${value}';
      case ExprType.VFloat if (Std.is(value, String)):
        Std.parseFloat(value);
      case ExprType.VInt if (Std.is(value, String)):
        Std.parseInt(value);
      case ExprType.VDate if (Std.is(value, String)):
        Date.fromString(value);
      case ExprType.VDate if (Std.is(value, Float)):
        Date.fromTime(value);
      #if js 
      case ExprType.VBytes if (Std.is(value, js.node.Buffer)):
        (value: js.node.Buffer).hxToBytes();
      #end
      case ExprType.VBytes if (Std.is(value, String)):
        haxe.io.Bytes.ofString(value);
      case ExprType.VGeometry(_):
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
      var nonNull = new Map();
      for (field in row.keys()) {
        var value = parseValue(
          row[field], 
          types.get(field)
        );
        if (nest) {
          var parts = field.split(SqlFormatter.FIELD_DELIMITER);
          var table = parts[0];
          var name = parts[1];
          var target: DynamicAccess<Any> =
            if (!res.exists(table)) res[table] = {};
            else res[table];
          target[name] = value;
          if (value != null) nonNull.set(table, true);
        } else {
          res[field] = value;
        }
      }
      if (nest) {
        for (table in res.keys())
          if (!nonNull.exists(table))
            res.remove(table);
      }
      return cast res;
    }
  }
}