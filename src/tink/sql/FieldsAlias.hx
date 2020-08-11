package tink.sql;

import haxe.DynamicAccess;
import tink.sql.Expr;

typedef Alias<T> = {
  alias:String,
  fields:T
}

class FieldsAlias {
  public static function create<Fields>(alias:String, fields:Fields):Fields {
    var res: DynamicAccess<ExprData<Dynamic>> = cast fields;
    for (name => field in res) {
      res[name] = switch field {
        case EField(_, name): new Field(alias, name);
        default: null;
      }
    }
    return cast res;
  }
}