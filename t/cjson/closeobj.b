implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	Token: import cjson;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(6);

	json1 := array of byte "  {}  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := Token.new(json1); t1.openobj(); t1.closeobj(); }
	ok_mem(mem);
	
	t := Token.new(array of byte "  ");
	ex := "";
	{ t.closeobj(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = Token.new(array of byte " true ");
	ex = "";
	{ t.closeobj(); } exception e { "*" => ex=e; }
	eq(ex, "expected '}'", "expected '}'");

	t = Token.new(array of byte " } ");
	ex = "";
	{ t.closeobj(); } exception e { "*" => ex=e; }
	eq(ex, "closing non-opened object", "closing non-opened object");

	t = Token.new(array of byte " } ");
	t.stack[0] = byte '[';
	t.depth = 1;
	ex = "";
	{ t.closeobj(); } exception e { "*" => ex=e; }
	eq(ex, "closing non-opened object", "closing non-opened object");

	t = Token.new(array of byte " {}  ,  true ");
	t.openobj();
	t.closeobj();
	eq_int(t.pos, 8, "pos == 8");
}

