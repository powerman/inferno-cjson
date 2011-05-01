implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	Token2JSON: import cjson;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(23);

	keys : ref CJSON->Keys;
	j : ref Token2JSON;

	keys = cjson->makekeys(array[] of { "key1", "key2" });
	j = Token2JSON.new(64);

	{ j.key(keys, 0); } exception e { "*" => catched(e); }
	raised("cjson:non-key expected", nil);

	{ j	.obj().close()
		.arr().close()
		.str(nil)
		.num(0)
		.bignum(big 0)
		.realnum(0.0)
		.bool(0)
		.null()
		;
	} exception e { "*" => catched(e); }
	raised("", "value list");

	j.arr();
	{ j	.obj().close()
		.arr().close()
		.str(nil)
		.num(0)
		.bignum(big 0)
		.realnum(0.0)
		.bool(0)
		.null()
		;
	} exception e { "*" => catched(e); }
	raised("", "value list in array");
	j.close();

	j.obj();
	{ j.obj(); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);
	{ j.arr(); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);
	{ j.str(""); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);
	{ j.num(0); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);
	{ j.bignum(big 0); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);
	{ j.realnum(0.0); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);
	{ j.bool(0); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);
	{ j.null(); } exception e { "*" => catched(e); }
	raised("cjson:key expected", nil);

	j = Token2JSON.new(64);
	j.obj();
	{ j.key(keys, 0).obj().close(); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).arr().close(); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).key(keys, 0); } exception e { "*" => catched(e); }
	raised("cjson:non-key expected", nil);
	{ j.null(); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).str(""); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).num(0); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).bignum(big 0); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).realnum(0.0); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).bool(1); } exception e { "*" => catched(e); }
	raised("", nil);
	{ j.key(keys, 0).null(); } exception e { "*" => catched(e); }
	raised("", nil);
	j.close();

	{ j	.obj()
			.key(keys, 0)	.str("")
			.key(keys, 0)	.num(0)
			.key(keys, 0)	.arr()
						.str("")
						.num(0)
						.obj()
							.key(keys, 0)	.null()
							.key(keys, 1)	.bool(1)
						.close()
					.close()
			.key(keys, 0)	.obj()
					.close()
		.close()
		;
	} exception e { "*" => catched(e); }
	raised("", "complex struct");
}

