package tink.sql;

import tink.sql.Expr;

typedef Alias<T> = {
  alias:String,
  fields:T
}

abstract FieldsAlias<T>(Alias<T>) {
  public function new(alias, fields) {
    this = {
      alias: alias,
      fields: fields
    }
  }
  
  @:op(a.b) public function read<F, O>(name:String)
    return switch (cast Reflect.field(this.fields, name): ExprData<F>) {
      case null: null;
      case EField(_, name): new Field(this.alias, name);
      default: null;
    }
}