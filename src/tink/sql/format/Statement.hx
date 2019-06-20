package tink.sql.format;

private enum Part {
  Sql(query:String);
  Ident(name:String);
  Value(value:Any);
}

abstract Statement(Array<Part>) from Array<Part> to Array<Part> {
  public static function ident(name:String):Statement
    return [Ident(name)];

  public static function value(value:Any):Statement
    return [Value(value)];

  public static function create(statements: Array<Statement>): Statement {
    var res = [];
    for (statement in statements)
      res.concat(statement);
    return res;
  }
  
  @:from public static function fromString(query:String):Statement
    return switch query {
      case null | '': [];
      case v: [Sql(query)];
    }
}