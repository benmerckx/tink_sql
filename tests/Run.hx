package tests;

import tink.unit.*;
import tink.testrunner.*;
import tink.sql.drivers.*;

class Run {
  static function main() {
    var mysql = new Db('test', new MySql({
      host: '127.0.0.1',
      user: env('DB_USERNAME', 'root'),
      password: env('DB_PASSWORD', '')
    }));
    var sqlite = new Db('test', new Sqlite(function(db) return ':memory:'));
    Fixture.load('init');
    Runner.run(TestBatch.make([
      new TestAlias(mysql),
      new TestCount(mysql),
      new TestInfo(mysql),
      new TestDelete(mysql),
      new TestInsert(mysql),
      new TestUpdate(mysql),
      new TestJoins(mysql),
      new TestUnion(mysql),
      new TestTypes(mysql),
      new TestSelect(mysql),
      new TestFormat(mysql),
      new TestStrings(mysql),
      new TestGeometry(mysql),
      new TestExpr(mysql),
      new TestSchema(mysql),
      //new TestSubquery(mysql),
      #if nodejs
      new TestProcedure(mysql),
      #end

      new TestAlias(sqlite),
      new TestCount(sqlite),
      new TestInfo(sqlite),
      new TestDelete(sqlite),
      new TestInsert(sqlite),
      new TestUpdate(sqlite),
      new TestJoins(sqlite),
      new TestUnion(sqlite),
      new TestTypes(sqlite),
      new TestSelect(sqlite),
      new TestFormat(sqlite),
      new TestStrings(sqlite),
      new TestExpr(sqlite),
      //new TestSubquery(sqlite),
      new TestExpr(sqlite),
      new TestIssue104()
    ])).handle(Runner.exit);
  }
  
  static function env(key, byDefault)
    return switch Sys.getEnv(key) {
      case null: byDefault; 
      case v: v;
    }
}
