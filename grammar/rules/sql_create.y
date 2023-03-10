sql_create_as_stmt:
    CREATE_P sql_opt_temp TABLE sql_create_as_target AS sql_select_stmt sql_opt_with_data {
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_CREATE_AS, Concat(std::move($4), {
            Attr(Key::SQL_CREATE_AS_TEMP, $2),
            Attr(Key::SQL_CREATE_AS_STATEMENT, ctx.Add(@6, proto::NodeType::OBJECT_SQL_SELECT, std::move($6))),
            Attr(Key::SQL_CREATE_AS_WITH_DATA, $7),
        }));
    }
  | CREATE_P sql_opt_temp TABLE IF_P NOT EXISTS sql_create_as_target AS sql_select_stmt sql_opt_with_data {
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_CREATE_AS, Concat(std::move($7), {
            Attr(Key::SQL_CREATE_AS_IF_NOT_EXISTS, Bool(Loc({@4, @5, @6}), true)),
            Attr(Key::SQL_CREATE_AS_TEMP, $2),
            Attr(Key::SQL_CREATE_AS_STATEMENT, ctx.Add(@9, proto::NodeType::OBJECT_SQL_SELECT, std::move($9))),
            Attr(Key::SQL_CREATE_AS_WITH_DATA, $10),
        }));
    }
    ;

sql_create_as_target:
    sql_qualified_name sql_opt_column_list sql_opt_with sql_on_commit_option {
        $$ = {
            Attr(Key::SQL_CREATE_AS_NAME, std::move($1)),
            Attr(Key::SQL_CREATE_AS_COLUMNS, ctx.Add(@2, std::move($2))),
            Attr(Key::SQL_CREATE_AS_ON_COMMIT, $4)
        };
    }
    ;
    
sql_create_stmt:
    CREATE_P sql_opt_temp TABLE sql_qualified_name '(' sql_opt_table_element_list ')' sql_on_commit_option {
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_CREATE, {
            Attr(Key::SQL_CREATE_TABLE_TEMP, $2),
            Attr(Key::SQL_CREATE_TABLE_NAME, std::move($4)),
            Attr(Key::SQL_CREATE_TABLE_ELEMENTS, ctx.Add(Loc({@5, @6, @7}), std::move($6))),
            Attr(Key::SQL_CREATE_TABLE_ON_COMMIT, $8),
        });
    }
    ;

sql_opt_table_element_list:
    sql_table_element_list  { $$ = std::move($1); }
  | %empty                  { $$ = {}; }
    ;

sql_table_element_list:
    sql_table_element                             { $$ = { $1 }; }
  | sql_table_element_list ',' sql_table_element  { $1.push_back(std::move($3)); $$ = std::move($1); }
    ;

sql_table_element:
    sql_column_def        { $$ = { std::move($1) }; }
  | sql_table_constraint  { $$ = { std::move($1) }; }
    ;

sql_column_def:
    sql_col_id sql_typename sql_create_generic_options sql_col_qual_list {
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_COLUMN_DEF, {
            Attr(Key::SQL_COLUMN_DEF_NAME, Ident(@1)),
            Attr(Key::SQL_COLUMN_DEF_TYPE, std::move($2)),
            Attr(Key::SQL_COLUMN_DEF_OPTIONS, std::move($3)),
            Attr(Key::SQL_COLUMN_DEF_CONSTRAINTS, ctx.Add(@4, std::move($4)))
        });
    }
    ;

sql_col_qual_list:
    sql_col_qual_list sql_col_constraint    { $1.push_back(std::move($2)); $$ = std::move($1); }
  | %empty                                  { $$ = {}; }
    ;

sql_col_constraint:
    CONSTRAINT sql_name sql_col_constraint_elem {
        $3.push_back(Attr(Key::SQL_COLUMN_CONSTRAINT_NAME, Ident(@2)));
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_COLUMN_CONSTRAINT, std::move($3));
    }
  | sql_col_constraint_elem { $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_COLUMN_CONSTRAINT, std::move($1)); }
  | sql_col_constraint_attr { $$ = std::move($1); }
  | COLLATE sql_any_name    { $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_COLUMN_CONSTRAINT, {
        Attr(Key::SQL_COLUMN_CONSTRAINT_TYPE, Enum(@$, proto::ColumnConstraint::COLLATE)),
        Attr(Key::SQL_COLUMN_CONSTRAINT_COLLATE, ctx.Add(@2, std::move($2))),
    });
  }
    ;

sql_col_constraint_attr:
    DEFERRABLE              { $$ = Enum(@$, proto::ConstraintAttribute::DEFERRABLE); }
  | NOT DEFERRABLE          { $$ = Enum(@$, proto::ConstraintAttribute::NOT_DEFERRABLE); }
  | INITIALLY DEFERRED      { $$ = Enum(@$, proto::ConstraintAttribute::INITIALLY_DEFERRED); }
  | INITIALLY IMMEDIATE     { $$ = Enum(@$, proto::ConstraintAttribute::INITIALLY_IMMEDIATE); }
    ;

sql_opt_definition:
    WITH sql_definition     { $$ = std::move($2); }
  | %empty                  { $$ = {}; }
    ;

sql_definition: '(' sql_def_list ')' { $$ = std::move($2); }

sql_def_list: 
    sql_def_elem                    { $$ = { std::move($1) }; }
  | sql_def_list ',' sql_def_elem   { $1.push_back($3); $$ = std::move($1); }
    ;

sql_def_elem:
    sql_col_label '=' sql_def_arg {
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_DEF_ARG, {
            Attr(Key::SQL_DEFINITION_ARG_KEY, std::move(Ident(@1))),
            Attr(Key::SQL_DEFINITION_ARG_VALUE, std::move(std::move($3))),
        });
    }
    ;

sql_def_arg:
    sql_func_type           { $$ = std::move($1); }
  | sql_reserved_keywords   { $$ = Ident(@1); }
  | sql_qual_all_op         { $$ = std::move($1); }
  | sql_numeric_only        { $$ = std::move($1); }
  | SCONST                  { $$ = Const(@1, proto::AConstType::STRING); }
  | NONE                    { $$ = {}; }
    ;

sql_numeric_only:
    FCONST              { $$ = Const(@$, proto::AConstType::FLOAT); }
  | '+' FCONST          { $$ = Const(@$, proto::AConstType::FLOAT); }
  | '-' FCONST          { $$ = Const(@$, proto::AConstType::FLOAT); }
  | sql_signed_iconst   { $$ = std::move($1); }
    ;

sql_signed_iconst:
    ICONST      { $$ = Const(@$, proto::AConstType::INTEGER); }
  | '+' ICONST  { $$ = Const(@$, proto::AConstType::INTEGER); }
  | '-' ICONST  { $$ = Const(@$, proto::AConstType::INTEGER); }
    ;

// XXX omitted SETOF
sql_func_type:
    sql_typename { $$ = std::move($1); }
    ;

// XXX omitted identity and foreign
sql_col_constraint_elem:
    NOT NULL_P                { $$ = { Attr(Key::SQL_COLUMN_CONSTRAINT_TYPE, Enum(@$, proto::ColumnConstraint::NOT_NULL)) }; }
  | NULL_P                    { $$ = { Attr(Key::SQL_COLUMN_CONSTRAINT_TYPE, Enum(@$, proto::ColumnConstraint::NULL_)) }; }
  | UNIQUE sql_opt_definition { $$ = {
        Attr(Key::SQL_COLUMN_CONSTRAINT_TYPE, Enum(@$, proto::ColumnConstraint::UNIQUE)),
        Attr(Key::SQL_COLUMN_CONSTRAINT_DEFINITION, ctx.Add(@2, std::move($2))),
    };
  }
  | PRIMARY KEY sql_opt_definition { $$ = {
        Attr(Key::SQL_COLUMN_CONSTRAINT_TYPE, Enum(@$, proto::ColumnConstraint::PRIMARY_KEY)),
        Attr(Key::SQL_COLUMN_CONSTRAINT_DEFINITION, ctx.Add(@3, std::move($3))),
    };
  }
  | CHECK_P '(' sql_a_expr ')' sql_opt_no_inherit { $$ = {
        Attr(Key::SQL_COLUMN_CONSTRAINT_TYPE, Enum(@$, proto::ColumnConstraint::CHECK)),
        Attr(Key::SQL_COLUMN_CONSTRAINT_VALUE, ctx.Add(std::move($3))),
        Attr(Key::SQL_COLUMN_CONSTRAINT_NO_INHERIT, std::move($5)),
    };
  }
  | DEFAULT sql_b_expr { $$ = {
        Attr(Key::SQL_COLUMN_CONSTRAINT_TYPE, Enum(@$, proto::ColumnConstraint::DEFAULT)),
        Attr(Key::SQL_COLUMN_CONSTRAINT_VALUE, ctx.Add(std::move($2))),
    };
  }
    ;

sql_opt_no_inherit:
    NO INHERIT  { $$ = Bool(@1, true); }
  | %empty      { $$ = Bool(@$, false); }
    ;

sql_create_generic_options:
    OPTIONS '(' sql_generic_option_list ')'     { $$ = ctx.Add(@$, std::move($3)); }
  | %empty                                      { $$ = {}; }
    ;

sql_generic_option_list:
    sql_generic_option_elem                                 { $$ = { std::move($1) };  }
  | sql_generic_option_list ',' sql_generic_option_elem     { $1.push_back(std::move($3)); $$ = std::move($1); }
    ;

sql_generic_option_elem:
    sql_col_label SCONST {
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_GENERIC_OPTION, {
            Attr(Key::SQL_GENERIC_OPTION_KEY, Ident(@1)),
            Attr(Key::SQL_GENERIC_OPTION_VALUE, Const(@2, sx::AConstType::STRING)),
        });
    }
    ;

sql_opt_column_list:
    '(' sql_column_list ')' { $$ = std::move($2); }
  | %empty                  { $$ = {}; }

sql_column_list:
    sql_column_elem                     { $$ = { Ident(@1) }; }
  | sql_column_list ',' sql_column_elem { $1.push_back(Ident(@3)); $$ = std::move($1); }
    ;

sql_column_elem: sql_col_id;

sql_opt_with_data:
    WITH DATA_P         { $$ = Bool(@$, true); }
  | WITH NO DATA_P      { $$ = Bool(@$, false); }
  | %empty              { $$ = Null(); }
    ;

sql_opt_temp:
    TEMPORARY           { $$ = Enum(@$, proto::TempType::LOCAL); }
  | TEMP                { $$ = Enum(@$, proto::TempType::LOCAL); }
  | LOCAL TEMPORARY     { $$ = Enum(@$, proto::TempType::LOCAL); }
  | LOCAL TEMP          { $$ = Enum(@$, proto::TempType::LOCAL); }
  | GLOBAL TEMPORARY    { $$ = Enum(@$, proto::TempType::GLOBAL); }
  | GLOBAL TEMP         { $$ = Enum(@$, proto::TempType::GLOBAL); }
  | UNLOGGED            { $$ = Enum(@$, proto::TempType::UNLOGGED); }
  | %empty              { $$ = Null(); }
    ;

sql_on_commit_option: 
    ON COMMIT DROP              { $$ = Enum(@$, proto::OnCommitOption::DROP); }
  | ON COMMIT DELETE_P ROWS     { $$ = Enum(@$, proto::OnCommitOption::DELETE_ROWS); }
  | ON COMMIT PRESERVE ROWS     { $$ = Enum(@$, proto::OnCommitOption::PRESERVE_ROWS); }
  | %empty                      { $$ = Null(); }
  ;

// XXX omitted reloptions and OIDS
sql_opt_with:
    %empty          { $$ = Null(); }
    ;

sql_table_constraint:
    CONSTRAINT sql_name sql_table_constraint_elem {
        $3.push_back(Attr(Key::SQL_TABLE_CONSTRAINT_NAME, Ident(@2)));
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_TABLE_CONSTRAINT, std::move($3));
    }
  | sql_table_constraint_elem {
        $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_TABLE_CONSTRAINT, std::move($1));
    }
    ;

sql_existing_index:
    USING INDEX sql_col_id  { $$ = Ident(@3); }
    ;

sql_table_constraint_elem:
    CHECK_P '(' sql_a_expr ')' sql_table_constraint_attr_list { $$ = {
        Attr(Key::SQL_TABLE_CONSTRAINT_TYPE, Enum(@$, proto::TableConstraint::CHECK)),
        Attr(Key::SQL_TABLE_CONSTRAINT_ARGUMENT, ctx.Add(std::move($3))),
    }; }
  | UNIQUE sql_existing_index sql_opt_definition sql_table_constraint_attr_list { $$ = {
        Attr(Key::SQL_TABLE_CONSTRAINT_TYPE, Enum(@$, proto::TableConstraint::UNIQUE)),
        Attr(Key::SQL_TABLE_CONSTRAINT_INDEX, $2),
        Attr(Key::SQL_TABLE_CONSTRAINT_DEFINITION, ctx.Add(@3, std::move($3))),
        Attr(Key::SQL_TABLE_CONSTRAINT_ATTRIBUTES, ctx.Add(@4, std::move($4))),
    }; }
  | UNIQUE sql_opt_column_list sql_opt_definition sql_table_constraint_attr_list { $$ = {
        Attr(Key::SQL_TABLE_CONSTRAINT_TYPE, Enum(@1, proto::TableConstraint::UNIQUE)),
        Attr(Key::SQL_TABLE_CONSTRAINT_COLUMNS, ctx.Add(@2, std::move($2))),
        Attr(Key::SQL_TABLE_CONSTRAINT_DEFINITION, ctx.Add(@3, std::move($3))),
        Attr(Key::SQL_TABLE_CONSTRAINT_ATTRIBUTES, ctx.Add(@4, std::move($4))),
    }; }
  | PRIMARY KEY sql_existing_index sql_opt_definition sql_table_constraint_attr_list { $$ = {
        Attr(Key::SQL_TABLE_CONSTRAINT_TYPE, Enum(@$, proto::TableConstraint::UNIQUE)),
        Attr(Key::SQL_TABLE_CONSTRAINT_INDEX, $3),
        Attr(Key::SQL_TABLE_CONSTRAINT_DEFINITION, ctx.Add(@4, std::move($4))),
        Attr(Key::SQL_TABLE_CONSTRAINT_ATTRIBUTES, ctx.Add(@5, std::move($5))),
    }; }
  | PRIMARY KEY sql_opt_column_list sql_opt_definition sql_table_constraint_attr_list { $$ = {
        Attr(Key::SQL_TABLE_CONSTRAINT_TYPE, Enum(@$, proto::TableConstraint::PRIMARY_KEY)),
        Attr(Key::SQL_TABLE_CONSTRAINT_COLUMNS, ctx.Add(@3, std::move($3))),
        Attr(Key::SQL_TABLE_CONSTRAINT_DEFINITION, ctx.Add(@4, std::move($4))),
        Attr(Key::SQL_TABLE_CONSTRAINT_ATTRIBUTES, ctx.Add(@5, std::move($5))),
    }; }
  | FOREIGN KEY sql_opt_column_list REFERENCES sql_qualified_name sql_opt_column_list sql_table_constraint_attr_list sql_key_match sql_key_actions { $$ = {
        Attr(Key::SQL_TABLE_CONSTRAINT_TYPE, Enum(Loc({@1, @2}), proto::TableConstraint::FOREIGN_KEY)),
        Attr(Key::SQL_TABLE_CONSTRAINT_COLUMNS, ctx.Add(@3, std::move($3))),
        Attr(Key::SQL_TABLE_CONSTRAINT_REFERENCES_NAME, std::move($5)),
        Attr(Key::SQL_TABLE_CONSTRAINT_REFERENCES_COLUMNS, ctx.Add(@6, std::move($6))),
        Attr(Key::SQL_TABLE_CONSTRAINT_ATTRIBUTES, ctx.Add(@7, std::move($7))),
        Attr(Key::SQL_TABLE_CONSTRAINT_KEY_ACTIONS, ctx.Add(@9, std::move($9))),
        Attr(Key::SQL_TABLE_CONSTRAINT_KEY_MATCH, $8),
    }; }
    ;

sql_key_match:
    MATCH FULL      { $$ = Enum(@$, proto::KeyMatch::FULL); }
  | MATCH PARTIAL   { $$ = Enum(@$, proto::KeyMatch::PARTIAL); }
  | MATCH SIMPLE    { $$ = Enum(@$, proto::KeyMatch::SIMPLE); }
  | %empty          { $$ = Null(); }
    ;

sql_key_actions:
    sql_key_update  { $$ = { $1 }; }
  | sql_key_delete  { $$ = { $1 }; }
  | sql_key_update sql_key_delete { $$ = { $1, $2 }; }
  | sql_key_delete sql_key_update { $$ = { $1, $2 }; }
  | %empty          { $$ = {}; }
    ;

sql_key_update:
    ON UPDATE sql_key_action_command { $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_KEY_ACTION, {
        Attr(Key::SQL_KEY_ACTION_TRIGGER, Enum(Loc({@1, @2}), proto::KeyActionTrigger::UPDATE)),
        Attr(Key::SQL_KEY_ACTION_COMMAND, $3),
    }); }
    ;

sql_key_delete:
    ON DELETE_P sql_key_action_command { $$ = ctx.Add(@$, proto::NodeType::OBJECT_SQL_KEY_ACTION, {
        Attr(Key::SQL_KEY_ACTION_TRIGGER, Enum(Loc({@1, @2}), proto::KeyActionTrigger::DELETE)),
        Attr(Key::SQL_KEY_ACTION_COMMAND, $3),
    }); }
    ;

sql_key_action_command:
    NO ACTION     { $$ = Enum(@$, proto::KeyActionCommand::NO_ACTION); }
  | RESTRICT      { $$ = Enum(@$, proto::KeyActionCommand::RESTRICT); }
  | CASCADE       { $$ = Enum(@$, proto::KeyActionCommand::CASCADE); }
  | SET NULL_P    { $$ = Enum(@$, proto::KeyActionCommand::SET_NULL); }
  | SET DEFAULT   { $$ = Enum(@$, proto::KeyActionCommand::SET_DEFAULT); }
    ;

sql_table_constraint_attr_list:
    sql_table_constraint_attr_list sql_table_constraint_attr_elem {
      $1.push_back($2);
      $$ = std::move($1);
    }
  | %empty { $$ = {}; }
    ;

sql_table_constraint_attr_elem:
    NOT DEFERRABLE        { $$ = Enum(@$, proto::ConstraintAttribute::DEFERRABLE); }
  | DEFERRABLE            { $$ = Enum(@$, proto::ConstraintAttribute::DEFERRABLE); }
  | INITIALLY IMMEDIATE   { $$ = Enum(@$, proto::ConstraintAttribute::DEFERRABLE); }
  | INITIALLY DEFERRED    { $$ = Enum(@$, proto::ConstraintAttribute::DEFERRABLE); }
  | NOT VALID             { $$ = Enum(@$, proto::ConstraintAttribute::DEFERRABLE); }
  | NO INHERIT            { $$ = Enum(@$, proto::ConstraintAttribute::DEFERRABLE); }
    ;
