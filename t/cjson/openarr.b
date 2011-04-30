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

	plan(6);

	json1 := array of byte "  [ 1, 2 ]  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.arr(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	ex := "";
	{ t.arr(); } exception e { "*" => ex=e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = JSON2Token.new(array of byte " true ");
	ex = "";
	{ t.arr(); } exception e { "*" => ex=e; }
	eq(ex, "expected '['", "expected '['");

	t = JSON2Token.new(array of byte " [[[[[[[[[[[[[[[[[ ");
	for(i=0;i<16;i++)
		t.arr();
	eq_int(t.depth, 16, "depth == 16");
	ex = "";
	{ t.arr(); } exception e { "*" => ex=e; }
	eq(ex, "stack overflow", "stack overflow");

	t = JSON2Token.new(array of byte " [ 1, 2 ] ");
	t.arr();
	eq_int(t.pos, 3, "pos == 3");
}
