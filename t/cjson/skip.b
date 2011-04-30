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

	plan(13);

	json1 := array of byte "  {\"key\": \"value\", \"k2\" :[1, 2,{\"k\":0}],\"x\":-1}  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.skip(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	ex := "";
	{ t.skip(); } exception e { "*" => ex = e; }
	eq(ex, "unexpected EOF", "unexpected EOF");
	
	t = JSON2Token.new(array of byte " X ");
	ex = "";
	{ t.skip(); } exception e { "*" => ex = e; }
	eq(ex, "expected json token", "expected json token");

	t = JSON2Token.new(array of byte " \"X\" ");
	t.skip();
	eq_int(t.pos, 5, "skip string to EOF");

	t = JSON2Token.new(array of byte " \"X\\\"Y\" , -2.3e+12 ,[],{},true,false,null");
	t.skip();
	eq_int(t.pos, 10, "skip string");
	t.skip();
	eq_int(t.pos, 20, "skip number");
	t.skip();
	eq_int(t.pos, 23, "skip empty array");
	t.skip();
	eq_int(t.pos, 26, "skip empty object");
	t.skip();
	eq_int(t.pos, 31, "skip true");
	t.skip();
	eq_int(t.pos, 37, "skip false");
	t.skip();
	eq_int(t.pos, 41, "skip null");

	t = JSON2Token.new(json1);
	t.skip();
	eq_int(t.pos, len json1, "skip complex struct");

	t = JSON2Token.new(array of byte "[1,2,3,X,5]");
	ex = "";
	{ t.skip(); } exception e { "*" => ex = e; }
	eq(ex, "expected json token", "expected json token (deep)");
}

