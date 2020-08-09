package tests;

@:asserts
class TestInfo extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();
  
  static function sorted<A>(i:Iterable<A>) {
    var ret = Lambda.array(i);
    ret.sort(Reflect.compare);
    return ret;
  }
  
  public function info() {
    asserts.assert(db.name == 'test');
    asserts.assert(sorted(db.tableNames()).join(',') == 'Geometry,Post,PostTags,Schema,StringTypes,Types,UniqueTable,User,alias');
    asserts.assert(sorted(db.tableInfo('Post').columnNames()).join(',') == 'author,content,id,title');
    return asserts.done();
  }
}