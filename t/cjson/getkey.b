implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	JSON2Token: import cjson;

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
		F_QUOTED	=> "key\":xx",
		F_OTHER		=> "other",
	});

	t := JSON2Token.new(array of byte " \"keyxx\" : ");

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ pos := t.pos; t.getkey(KEYS); t.pos = pos; }
	ok_mem(mem);
	
	t = JSON2Token.new(array of byte "  ");
	{ t.getkey(KEYS); } exception e { "*" => catched(e); }
	raised("cjson:unexpected EOF", nil);
	
	t = JSON2Token.new(array of byte " } ");
	eq_int(t.getkey(KEYS), CJSON->END_OBJ, "end object");

	t = JSON2Token.new(array of byte " 1 ");
	{ t.getkey(KEYS); } exception e { "*" => catched(e); }
	raised("cjson:expected '\"'", nil);
	
	t = JSON2Token.new(array of byte " \"keyxx : ");
	{ t.getkey(KEYS); } exception e { "*" => catched(e); }
	raised("cjson:non-terminated string", nil);

	t = JSON2Token.new(array of byte " \"key\\\":xx\" : ");
	eq_int(t.getkey(KEYS), F_QUOTED, "key\\\":xx");
	eq_int(t.pos, 14, "skip quoted key");

	t = JSON2Token.new(array of byte " \"keyxx\"  ");
	{ t.getkey(KEYS); } exception e { "*" => catched(e); }
	raised("cjson:expected ':'", nil);

	t = JSON2Token.new(array of byte " \"keyxx\" : 123 ");
	eq_int(t.getkey(KEYS), F_KEYXX, "KEYXX");
	eq_int(t.pos, 11, "skip spaces");
	
	t = JSON2Token.new(array of byte " \"nosuch\" : 123 ");
	eq_int(t.getkey(KEYS), CJSON->UNK_KEY, "UNK_KEY nosuch");

	t = JSON2Token.new(array of byte " \"keyxxxx\" : 123 ");
	eq_int(t.getkey(KEYS), CJSON->UNK_KEY, "UNK_KEY keyxxxx");

	t = JSON2Token.new(array of byte " \"oTHER\" : 123 ");
	eq_int(t.getkey(KEYS), CJSON->UNK_KEY, "UNK_KEY oTHER");
}

