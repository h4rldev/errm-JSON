-ifndef (ERRM_JSON_HRL).
-define (ERRM_JSON_HRL, true).

-type json_term() :: null | true | false | number() | binary() | list() | atom() | [json_term()] | #{binary() => json_term()} | #{}.
-type parse_options() ::  #{return_strings => boolean(), max_depth => non_neg_integer()}.
-type encode_options() :: #{pretty => boolean(), indent => integer(), order => [atom()]}.
-endif.
