implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	JSON2Token: import cjson;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(8);

	json1 := array of byte "  []  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.arr(); t1.close(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	{ t.close(); } exception e { "*" => catched(e); }
	raised("cjson:unexpected EOF", nil);
	
	t = JSON2Token.new(array of byte " true ");
	t.stack[0] = byte ']';
	t.depth = 1;
	eq_int(t.close(), 0, "return 0");
	eq_int(t.pos, 1, "pos wan't changed");

	t = JSON2Token.new(array of byte " ] ");
	{ t.close(); } exception e { "*" => catched(e); }
	raised("cjson:not end of current object/array", nil);

	t = JSON2Token.new(array of byte " ] ");
	t.stack[0] = byte '}';
	t.depth = 1;
	{ t.close(); } exception e { "*" => catched(e); }
	raised("cjson:not end of current object/array", nil);

	t = JSON2Token.new(array of byte " []  ,  true ");
	t.arr();
	eq_int(t.close(), 1, "return 1");
	eq_int(t.pos, 8, "pos == 8");
}

