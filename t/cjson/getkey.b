implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	Token: import cjson;

F_KEY,
F_KEYXX,
F_KEYX,
F_QUOTED,
F_OTHER: con iota;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(13);

	KEYS := cjson->makekeys(array[] of {
		F_KEY		=> "key",
		F_KEYXX		=> "keyxx",
		F_KEYX		=> "keyx",
		F_QUOTED	=> "key\\\":xx",
		F_OTHER		=> "other",
	});

	t := Token.new(array of byte " \"keyxx\" : ");

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ pos := t.pos; t.getkey(KEYS); t.pos = pos; }
	ok_mem(mem);
	
	t = Token.new(array of byte "  ");
	ex := "";
	{ t.getkey(KEYS); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = Token.new(array of byte " } ");
	eq_int(t.getkey(KEYS), CJSON->END_OBJ, "end object");

	t = Token.new(array of byte " 1 ");
	ex = "";
	{ t.getkey(KEYS); } exception e { "*" => ex=e; }
	eq(ex, "expected '\"'", "expected '\"'");
	
	t = Token.new(array of byte " \"keyxx : ");
	ex = "";
	{ t.getkey(KEYS); } exception e { "*" => ex=e; }
	eq(ex, "non-terminated string", "non-terminated string");

	t = Token.new(array of byte " \"key\\\":xx\" : ");
	eq_int(t.getkey(KEYS), F_QUOTED, "key\\\":xx");
	eq_int(t.pos, 14, "INTENTIONAL BUG: key names doesn't unquoted");

	t = Token.new(array of byte " \"keyxx\"  ");
	ex = "";
	{ t.getkey(KEYS); } exception e { "*" => ex=e; }
	eq(ex, "expected ':'", "expected ':'");

	t = Token.new(array of byte " \"keyxx\" : 123 ");
	eq_int(t.getkey(KEYS), F_KEYXX, "KEYXX");
	eq_int(t.pos, 11, "skip spaces");
	
	t = Token.new(array of byte " \"nosuch\" : 123 ");
	eq_int(t.getkey(KEYS), CJSON->UNK_KEY, "UNK_KEY nosuch");

	t = Token.new(array of byte " \"keyxxxx\" : 123 ");
	eq_int(t.getkey(KEYS), CJSON->UNK_KEY, "UNK_KEY keyxxxx");

	t = Token.new(array of byte " \"oTHER\" : 123 ");
	eq_int(t.getkey(KEYS), CJSON->UNK_KEY, "UNK_KEY oTHER");
}

