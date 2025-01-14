grammar Toml;

@header {package cc.ekblad.toml.parser;}

/*
 * Parser Rules
 */

document : expression (NL expression)* EOF ;

expression : key_value comment | table comment | comment ;

comment: COMMENT? ;

key_value : key '=' value ;

key : simple_key | dotted_key ;

simple_key : quoted_key | unquoted_key ;

/* Ugly hack to explicitly include tokens that may also be other things.
 * The converter step needs to further process unquoted keys, to split float-looking keys into dotted keys and
 * reject keys containing plus signs.
 */
unquoted_key : UNQUOTED_KEY | NAN | INF | BOOLEAN | LOCAL_DATE | FLOAT | integer ;

quoted_key :  BASIC_STRING | LITERAL_STRING ;

dotted_key : simple_key ('.' simple_key)+ ;

value : string | integer | floating_point | bool_ | date_time | array_ | inline_table ;

string : BASIC_STRING | ML_BASIC_STRING | LITERAL_STRING | ML_LITERAL_STRING ;

integer : DEC_INT | HEX_INT | OCT_INT | BIN_INT ;

floating_point : FLOAT | INF | NAN ;

bool_ : BOOLEAN ;

date_time : OFFSET_DATE_TIME | LOCAL_DATE_TIME | LOCAL_DATE | LOCAL_TIME ;

array_ : '[' array_values? comment_or_nl ']' ;

array_values : (comment_or_nl value comment_or_nl ',' array_values comment_or_nl) | comment_or_nl value comment_or_nl ','? ;

comment_or_nl : (COMMENT? NL)* ;

table : standard_table | array_table ;

standard_table : '[' key ']' ;

inline_table : '{' inline_table_keyvals '}' ;

inline_table_keyvals : inline_table_keyvals_non_empty? ;

inline_table_keyvals_non_empty : key '=' value (',' inline_table_keyvals_non_empty)? ;

array_table : '[' '[' key ']' ']' ;

/*
 * Lexer Rules
 */

WS : [ \t]+ -> skip ;
NL : ('\r'? '\n')+ ;
COMMENT : '#' (~[\r\n])* ;

fragment DIGIT : [0-9] ;
fragment ALPHA : [A-Za-z] ;

// booleans
BOOLEAN : 'true' | 'false' ;

// strings
fragment ESC : '\\' (["\\bfnrt] | UNICODE | EX_UNICODE) ;
fragment ML_ESC : '\\' '\r'? '\n' | ESC ;
fragment UNICODE : 'u' HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT ;
fragment EX_UNICODE : 'U' HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT ;
BASIC_STRING : '"' (ESC | ~["\\\n])*? '"' ;
ML_BASIC_STRING : '"""' (ML_ESC | ~[\\])*? '"""' '"'? '"'?;
LITERAL_STRING : '\'' (~['\n])*? '\'' ;
ML_LITERAL_STRING : '\'\'\'' (.)*? '\'\'\'' '\''? '\''?;
// floating point numbers
fragment EXP : ('e' | 'E') [+-]? ZERO_PREFIXABLE_INT ;
fragment ZERO_PREFIXABLE_INT : DIGIT (DIGIT | '_' DIGIT)* ;
fragment FRAC : '.' ZERO_PREFIXABLE_INT ;
FLOAT : DEC_INT ( EXP | FRAC EXP?) ;
INF : [+-]? 'inf' ;
NAN : [+-]? 'nan' ;
// integers
fragment HEX_DIGIT : [A-Fa-f] | DIGIT ;
fragment DIGIT_1_9 : [1-9] ;
fragment DIGIT_0_7 : [0-7] ;
fragment DIGIT_0_1 : [0-1] ;
DEC_INT : [+-]? (DIGIT | (DIGIT_1_9 (DIGIT | '_' DIGIT)+)) ;
HEX_INT : '0x' HEX_DIGIT (HEX_DIGIT | '_' HEX_DIGIT)* ;
OCT_INT : '0o' DIGIT_0_7 (DIGIT_0_7 | '_' DIGIT_0_7)* ;
BIN_INT : '0b' DIGIT_0_1 (DIGIT_0_1 | '_' DIGIT_0_1)* ;
// dates
fragment YEAR : DIGIT DIGIT DIGIT DIGIT ;
fragment MONTH : DIGIT DIGIT ;
fragment DAY : DIGIT DIGIT ;
fragment DELIM : 'T' | 't' | ' ' ;
fragment HOUR : DIGIT DIGIT ;
fragment MINUTE : DIGIT DIGIT ;
fragment SECOND : DIGIT DIGIT ;
fragment SECFRAC : '.' DIGIT+ ;
fragment NUMOFFSET : ('+' | '-') HOUR ':' MINUTE ;
fragment OFFSET : 'Z' | 'z' | NUMOFFSET ;
fragment PARTIAL_TIME : HOUR ':' MINUTE ':' SECOND SECFRAC? ;
fragment FULL_DATE : YEAR '-' MONTH '-' DAY ;
fragment FULL_TIME : PARTIAL_TIME OFFSET ;
OFFSET_DATE_TIME : FULL_DATE DELIM FULL_TIME ;
LOCAL_DATE_TIME : FULL_DATE DELIM PARTIAL_TIME ;
LOCAL_DATE : FULL_DATE ;
LOCAL_TIME : PARTIAL_TIME ;
// keys
UNQUOTED_KEY : (ALPHA | DIGIT | '-' | '_')+ ;
