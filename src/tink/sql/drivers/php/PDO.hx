package tink.sql.drivers.php;

import haxe.DynamicAccess;
import haxe.io.Bytes;
import tink.sql.Query;
import tink.sql.Info;
import tink.sql.Types;
import tink.sql.format.Sanitizer;
import tink.streams.Stream;
import tink.sql.format.MySqlFormatter;
import tink.sql.expr.ExprTyper;
import tink.sql.parse.ResultParser;
import tink.sql.drivers.MySqlSettings;
import php.db.PDO;
import php.db.PDOStatement;
import php.db.PDOException;

using tink.CoreApi;

class PDOMysql implements Driver {
  var settings:MySqlSettings;

  public function new(settings)
    this.settings = settings;
  
  function or<T>(value:Null<T>, byDefault: T)
    return value == null ? byDefault : value;

  public function open<Db:DatabaseInfo>(name:String, info:Db):Connection<Db> {
    return new PDOConnection(info,
      new PDO(
        'mysql:host=${or(settings.host, 'localhost')};'
        + 'port=${or(settings.port, 3306)};'
        + 'dbname=$name;charset=${or(settings.charset, 'utf8')}',
        settings.user,
        settings.password
      )
    );
  }
}

class PDOConnection<Db:DatabaseInfo> implements Connection<Db> implements Sanitizer {

  var db:Db;
  var cnx:PDO;
  var formatter:MySqlFormatter;
  var parser:ResultParser<Db>;

  public function new(db, cnx) {
    this.db = db;
    this.cnx = cnx;
    cnx.setAttribute(PDO.ATTR_ERRMODE, PDO.ERRMODE_EXCEPTION);
    // Workaround haxetink/tink_sql#108 and haxetink/tink_sql#109 for now
    // by disabling ONLY_FULL_GROUP_BY
    cnx.exec("SET sql_mode = ''");
    this.formatter = new MySqlFormatter(this);
    this.parser = new ResultParser(new ExprTyper(db));
  }

  public function value(v:Any):String {
    if (Std.is(v, Bool)) return v ? 'true' : 'false';
    if (v == null || Std.is(v, Int)) return '$v';
    if (Std.is(v, Bytes)) v = (cast v: Bytes).toString();
    return cnx.quote(v);
  }

  public function ident(s:String):String {
    if (s.indexOf("`") == -1) return "`"+s+"`";
    return tink.sql.drivers.MySql.getSanitizer(null).ident(s);
  }

  public function getFormatter()
    return formatter;

  public function execute<Result>(query:Query<Db,Result>):Result {
    inline function fetch(): Promise<PDOStatement> return run(formatter.format(query));
    return switch query {
      case Select(_) | Union(_) | CallProcedure(_): 
        Stream.promise(fetch().next(function (res:PDOStatement) {
          var row: Any;
          var parse = parser.lazyParser(query, formatter.isNested(query));
          return Stream.ofIterator({
            hasNext: function() {
              row = res.fetchObject();
              return row != false;
            },
            next: function () return parse(row)
          });
        }));
      case CreateTable(_, _) | DropTable(_) | AlterTable(_, _):
        fetch().next(function(_) return Noise);
      case Insert(_):
        fetch().next(function(_) return new Id(Std.parseInt(cnx.lastInsertId())));
      case Update(_) | Delete(_):
        fetch().next(function(res) return {rowsAffected: res.rowCount()});
      case ShowColumns(_):
        fetch().next(function(res:PDOStatement):Array<Column>
          return [for (row in res.fetchAll(PDO.FETCH_OBJ)) formatter.parseColumn(row)]
        );
      case ShowIndex(_):
        fetch().next(function (res) return formatter.parseKeys(
          [for (row in res.fetchAll(PDO.FETCH_OBJ)) row]
        ));
    }
  }

  function run(query:String):Promise<PDOStatement>
    return 
      try cnx.query(query) 
      catch (e: PDOException) 
        new Error(e.getCode(), e.getMessage());

  // haxetink/tink_streams#20
  public function syncResult<R, T: {}>(query:Query<Db,R>): Outcome<Array<T>, Error> {
    return switch query {
      case Select(_) | Union(_) | CallProcedure(_): 
        var parse = parser.lazyParser(query, formatter.isNested(query));
        try Success([
          for (row in cnx.query(formatter.format(query)).fetchAll(PDO.FETCH_OBJ))
            parse(row)
        ]) catch (e: PDOException)
          Failure(new Error(e.getCode(), e.getMessage()));
      default: throw 'Cannot iterate this query';
    }
  }
}
