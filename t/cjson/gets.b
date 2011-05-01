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

	plan(19);

	json1 := array of byte "  \"this is a string\" ,  ";

	mem:=getmem(); for(i:=0; i<10000; i++)
	{ t1 := JSON2Token.new(json1); t1.gets(); }
	ok_mem(mem);
	
	t := JSON2Token.new(array of byte "  ");
	{ t.gets(); } exception e { "*" => catched(e); }
	raised("cjson:unexpected EOF", nil);
	
	t = JSON2Token.new(array of byte " null ");
	{ t.gets(); } exception e { "*" => catched(e); }
	raised("cjson:expected '\"'", nil);
	
	t = JSON2Token.new(array of byte " \" ");
	{ t.gets(); } exception e { "*" => catched(e); }
	raised("cjson:non-terminated string", nil);
	
	t = JSON2Token.new(array of byte "  \"this is a string\" ,  null  ");
	eq(t.gets(), "this is a string", "return string");
	eq_int(t.pos, 24, "pos changed");

	t = JSON2Token.new(array of byte "  \"this is a \\\"quoted\\\" string\" ,  null  ");
	eq(t.gets(), "this is a \"quoted\" string", "return quoted string");

	t = JSON2Token.new(array of byte "  \"\\n\" ,  null  ");
	eq(t.gets(), "\n", "return \\n");
	t = JSON2Token.new(array of byte "  \"\\b\\f\\n\\r\\t\\\\\\'\\\"\" ,  null  ");
	eq(t.gets(), "\b\f\n\r\t\\'\"", "return \\b\\f\\n\\r\\t\\'\"");
	t = JSON2Token.new(array of byte "  \"\\\\\" ,  null  ");
	eq(t.gets(), "\\", "return \\");
	t = JSON2Token.new(array of byte "  \"\\Q\" ,  null  ");
	eq(t.gets(), "Q", "return Q");

	t = JSON2Token.new(array of byte "  \"\\u\" ,  null  ");
	{ t.gets(); } exception e { "*" => catched(e); }
	raised("cjson:bad \\u in string", nil);

	t = JSON2Token.new(array of byte "  \"\\u123-\" ,  null  ");
	{ t.gets(); } exception e { "*" => catched(e); }
	raised("cjson:bad \\u in string", nil);

	t = JSON2Token.new(array of byte "  \"<\\u0020>\" ,  null  ");
	eq(t.gets(), "< >", "return \\u0020");
	t = JSON2Token.new(array of byte "  \"<\\u00fF>\" ,  null  ");
	eq(t.gets(), "<\u00ff>", "return \\u00fF");
	t = JSON2Token.new(array of byte "  \"<\\u0000>\" ,  null  ");
	eq(t.gets(), "<\0>", "return \\u0000");
	t = JSON2Token.new(array of byte "  \"<\\u2026>\" ,  null  ");
	eq(t.gets(), "<…>", "return …");
	t = JSON2Token.new(array of byte "  \"<\\ufFfF>\" ,  null  ");
	eq(t.gets(), "<\uffff>", "return \\ufFfF");

	json2 := array of byte "  \"this is a quoted \\ufFfF \\u2026 \\u0000 \\b\\f\\n\\r\\t\\\\\\'\\\" string\" ,  ";

	mem=getmem(); for(i=0; i<10000; i++)
	{ t1 := JSON2Token.new(json2); t1.gets(); }
	ok_mem(mem);
}

