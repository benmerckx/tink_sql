package tests.fixture;

class Fixture {
  public static function load(file: String) {
    Sys.command('node', ['tests/fixture', 'tests/fixture/$file.sql']);
  }
}