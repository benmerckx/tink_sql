package tink.sql.drivers.node;

import js.node.Buffer;
import haxe.DynamicAccess;
import haxe.io.Bytes;
import tink.sql.Query;
import tink.sql.Info;
import tink.sql.Types;
import tink.sql.format.Sanitizer;
import tink.streams.Stream;
import tink.sql.format.MySqlFormatter;

import #if haxe3 js.lib.Error #else js.Error #end as JsError;

using tink.CoreApi;

typedef NodeSettings = {
  > MySqlSettings,
  ?connectionLimit:Int,
}

class MySql implements Driver {

  var settings:NodeSettings;

  public function new(settings) {
    this.settings = settings;
  }

  public function open<Db:DatabaseInfo>(name:String, info:Db):Connection<Db> {
    var cnx = NativeDriver.createPool({
      user: settings.user,
      password: settings.password,
      host: settings.host,
      port: settings.port,
      database: name,
      connectionLimit: settings.connectionLimit,
      charset: settings.charset,
    });

    return new MySqlConnection(info, cnx);
  }
}

class MySqlConnection<Db:DatabaseInfo> implements Connection<Db> implements Sanitizer {

  var cnx:NativeConnection;
  var db:Db;
  var formatter:MySqlFormatter;

  public function new(db, cnx) {
    this.db = db;
    this.cnx = cnx;
    this.formatter = new MySqlFormatter(this);
  }

  public function value(v:Any):String
    return NativeDriver.escape(if(Std.is(v, Bytes)) Buffer.hxFromBytes(v) else v);

  public function ident(s:String):String
    return NativeDriver.escapeId(s);

  public function getFormatter()
    return formatter;
  
  function toError<A>(error:JsError):Outcome<A, Error>
    return Failure(Error.withData(error.message, error));

  public function execute<Result>(query:Query<Db,Result>):Result {
    inline function fetch<T>(): Promise<T> return run(queryOptions(query));
    return switch query {
      case Select(_) | Union(_): 
        Stream.promise(fetch().next(function (res)
          return Stream.ofIterator(rowIterator(res, formatter.isNested(query)))
        ));
      case CallProcedure(_): 
        Stream.promise(fetch().next(function (res)
          return Stream.ofIterator(rowIterator(res[0], formatter.isNested(query)))
        ));
      case CreateTable(_, _) | DropTable(_) | AlterTable(_, _):
        fetch().next(function(_) return Noise);
      case Insert(_):
        fetch().next(function(res) return new Id(res.insertId));
      case Update(_):
        fetch().next(function(res) return {rowsAffected: (res.changedRows: Int)});
      case Delete(_):
        fetch().next(function(res) return {rowsAffected: (res.affectedRows: Int)});
      case ShowColumns(_):
        fetch().next(function(res:Array<MysqlColumnInfo>) 
          return res.map(formatter.parseColumn)
        );
      case ShowIndex(_):
        fetch().next(formatter.parseKeys);
    }
  }

  function queryOptions(query:Query<Db, Dynamic>): QueryOptions {
    var sql = formatter.format(query);
    #if sql_debug
    trace(sql);
    #end
    return switch query {
      case Select(_) | Union(_) | CallProcedure(_):
        {sql: sql, typeCast: typeCast, nestTables: formatter.isNested(query)}
      default:
        {sql: sql}
    }
  }

  function run<T>(options: QueryOptions):Promise<T>
    return Future.async(function (done) {
      cnx.query(options, function (err, res) {
        if (err != null) done(toError(err));
        else done(Success(cast res));
      });
    });

  function typeCast(field, next): Any {
    return switch field.type {
      case 'BLOB' | 'VAR_STRING':
        if(field.packet.charsetNr == 63) // binary = 63, see: https://dev.mysql.com/doc/internals/en/character-set.html#packet-Protocol::CharacterSet
          switch (field.buffer():Buffer) {
            case null: null;
            case buf: buf.hxToBytes();
          }
        else
          field.string();
      case 'TINY' if(field.length == 1):
        switch field.string() {
          case null: null;
          case v: v != '0';
        }
      case 'GEOMETRY':
        var v:Dynamic = field.geometry();
        // https://github.com/mysqljs/mysql/blob/310c6a7d1b2e14b63b572dbfbfa10128f20c6d52/lib/protocol/Parser.js#L342-L389
        if(v == null) {
          null;
        } else {
            if(Std.is(v, Array)) {
              if(Std.is(v[0], Array)) {
                if(Std.is(v[0][0], Array)) {
                  new geojson.MultiPolygon(
                    [for(polygon in (v:Array<Dynamic>))
                      [for(line in (polygon:Array<Dynamic>))
                        [for(point in (line:Array<Dynamic>))
                          new geojson.util.Coordinates(point.y, point.x)
                        ]
                      ]
                    ]
                  );
                } else {
                  // Polygon
                  throw 'Polygon parsing not implemented';
                }
              } else {
                // Line
                throw 'Line parsing not implemented';
              }
            } else {
              // Point
              new geojson.Point(v.y, v.x);
            }
        }
      default:
        next();
    }
  }

  function rowIterator<A>(result:Array<DynamicAccess<DynamicAccess<Any>>>, nest = false):Iterator<A> {
    var result:Array<A> =
      if (!nest) cast result
      else [for (row in result) {
        var rowCopy: DynamicAccess<DynamicAccess<Any>> = {};
        for (partName in row.keys()) {
          var part = row[partName],
              notNull = false;
          for (name in part.keys())
            if (part[name] != null) {
              notNull = true;
              break;
            }
          if (notNull)
            rowCopy[partName] = part;
        }
        (cast rowCopy : A);
      }];
    return result.iterator();
  }

}

@:jsRequire("mysql")
private extern class NativeDriver {
  static function escape(value:Any):String;
  static function escapeId(ident:String):String;
  static function createPool(config:Config):NativeConnection;
}

private typedef Config = {>MySqlSettings,
  public var database(default, null):String;
  @:optional public var connectionLimit(default, null):Int;
  @:optional public var charset(default, null):String;
}

private typedef QueryOptions = {
  sql:String,
  ?nestTables:Bool,
  ?typeCast:Dynamic->(Void->Dynamic)->Dynamic
}

private typedef NativeConnection = {
  function query(q: QueryOptions, cb:JsError->Dynamic->Void):Void;
  //function release():Void; -- doesn't seem to work
}