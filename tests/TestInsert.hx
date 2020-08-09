package tests;

@:asserts
class TestInsert extends Test {
  @:before public function before() return createTables();
  @:after public function after() return dropTables();
  
  public function insert()
    return insertUsers().next(function(insert:Int) return assert(insert > 0));
}