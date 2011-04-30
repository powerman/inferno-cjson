implement T;

include "opt/powerman/tap/module/t.m";
include "cjson.m";
	cjson: CJSON;
	JSON2Token: import cjson;

F_SOURCE,
F_SPORT,
F_SITE,
F_PLAYERS,
F_GAME,
F_BETTYPE,
F_HANDICAP,
F_NUM1,
F_NUM2,
F_VALUE,
F_X2,
F_X,
F_DATETIME: con iota;

KEYS: ref CJSON->Keys;

test()
{
	cjson = load CJSON CJSON->PATH;
	if(cjson == nil)
		bail_out("fail to load CJSON");

	plan(79);

	mem:=getmem(); for(i:=0; i<10000; i++)
	KEYS = cjson->makekeys(array[] of {
		F_SOURCE	=> "source",
		F_SPORT		=> "sport",
		F_SITE		=> "site",
		F_PLAYERS	=> "players",
		F_GAME		=> "game",
		F_BETTYPE	=> "bettype",
		F_HANDICAP	=> "handicap",
		F_NUM1		=> "num1",
		F_NUM2		=> "num2",
		F_VALUE		=> "value",
		F_X2		=> "x2",
		F_X		=> "x",
		F_DATETIME	=> "datetime",
	});
	KEYS = nil; ok_mem(mem);
	
	ex := "";
	{	KEYS = cjson->makekeys(array[] of {
			F_SOURCE	=> "source",
			F_SPORT		=> "",
			F_SITE		=> "site",
		});
	} exception e { "*" => ex = e; }
	eq(ex, "", "empty keys ignored");

	ex = "";
	{	KEYS = cjson->makekeys(array[] of {
			F_SOURCE	=> "source",
			F_SPORT		=> "source",
			F_SITE		=> "site",
		});
	} exception e { "*" => ex = e; }
	eq(ex, "duplicate keys", "duplicate keys");

	KEYS = cjson->makekeys(array[] of {
		F_SOURCE	=> "source",
		F_SPORT		=> "sport",
		F_SITE		=> "site",
		F_PLAYERS	=> "players",
		F_GAME		=> "game",
		F_BETTYPE	=> "bettype",
		F_HANDICAP	=> "handicap",
		F_NUM1		=> "num1",
		F_NUM2		=> "num2",
		F_VALUE		=> "value",
		F_X2		=> "x2",
		F_X		=> "x",
		F_DATETIME	=> "datetime",
	});
	ok(KEYS != nil, "KEYS not nil");

	K2ID := KEYS.key2id;

	eq_int(len K2ID, 256, "len K2ID == 256");
	nulls := 0;
	for(i = 0; i < len K2ID; i++) case i {
	'b' =>	ok(K2ID[i] != nil,			"[b] not nil");
		ok(K2ID[i].n == nil,			"… n nil");
		eq(string K2ID[i].tail, "ettype",	"… tail");
		eq_int(K2ID[i].id, F_BETTYPE,		"… id");
	'd' =>	ok(K2ID[i] != nil,			"[d] not nil");
		ok(K2ID[i].n == nil,			"… n nil");
		eq(string K2ID[i].tail, "atetime",	"… tail");
		eq_int(K2ID[i].id, F_DATETIME,		"… id");
	'g' =>	ok(K2ID[i] != nil,			"[g] not nil");
		ok(K2ID[i].n == nil,			"… n nil");
		eq(string K2ID[i].tail, "ame",		"… tail");
		eq_int(K2ID[i].id, F_GAME,		"… id");
	'h' =>	ok(K2ID[i] != nil,			"[h] not nil");
		ok(K2ID[i].n == nil,			"… n nil");
		eq(string K2ID[i].tail, "andicap",	"… tail");
		eq_int(K2ID[i].id, F_HANDICAP,		"… id");
	'n' =>	ok(K2ID[i] != nil,			"[n] not nil");
		ok(K2ID[i].n != nil,			"… n not nil");
		ok(K2ID[i].tail == nil,			"… tail nil");
		eq_int(K2ID[i].id, CJSON->UNK_KEY,	"… id UNK_KEY");
		next := K2ID[i].n;
		nextnulls := 0;
		ok(next['u'] != nil,			"… [u] not nil");
		for(j := 0; j < len next; j++)
			if(next[j] == nil)
				nextnulls++;
		eq_int(nextnulls, 256-1,		"… … all other elements nil");
		ok(next['u'].n != nil,			"… … n not nil");
		ok(next['u'].tail == nil,		"… … tail nil");
		eq_int(next['u'].id, CJSON->UNK_KEY,	"… … id UNK_KEY");
		next = next['u'].n;
		nextnulls = 0;
		ok(next['m'] != nil,			"… … [m] not nil");
		for(j = 0; j < len next; j++)
			if(next[j] == nil)
				nextnulls++;
		eq_int(nextnulls, 256-1,		"… … … all other elements nil");
		ok(next['m'].n != nil,			"… … … n not nil");
		ok(next['m'].tail == nil,		"… … … tail nil");
		eq_int(next['m'].id, CJSON->UNK_KEY,	"… … … id UNK_KEY");
		next = next['m'].n;
		nextnulls = 0;
		ok(next['1'] != nil,			"… … … [1] not nil");
		ok(next['2'] != nil,			"… … … [2] not nil");
		for(j = 0; j < len next; j++)
			if(next[j] == nil)
				nextnulls++;
		eq_int(nextnulls, 256-2,		"… … … … all other elements nil");
		ok(next['1'].n == nil,			"… … … … n nil [1]");
		ok(next['2'].n == nil,			"… … … … n nil [2]");
		ok(next['1'].tail == nil,		"… … … … tail nil [1]");
		ok(next['2'].tail == nil,		"… … … … tail nil [2]");
		eq_int(next['1'].id, F_NUM1,		"… … … … id [1]");
		eq_int(next['2'].id, F_NUM2,		"… … … … id [2]");
	'p' =>	ok(K2ID[i] != nil,			"[p] not nil");
		ok(K2ID[i].n == nil,			"… n nil");
		eq(string K2ID[i].tail,	"layers",	"… tail");
		eq_int(K2ID[i].id, F_PLAYERS,		"… id");
	's' =>	ok(K2ID[i] != nil,			"[s] not nil");
		ok(K2ID[i].n != nil,			"… n not nil");
		ok(K2ID[i].tail == nil,			"… tail nil");
		eq_int(K2ID[i].id, CJSON->UNK_KEY,	"… id UNK_KEY");
		next := K2ID[i].n;
		nextnulls := 0;
		ok(next['i'] != nil,			"… [i] not nil");
		ok(next['o'] != nil,			"… [o] not nil");
		ok(next['p'] != nil,			"… [p] not nil");
		for(j := 0; j < len next; j++)
			if(next[j] == nil)
				nextnulls++;
		eq_int(nextnulls, 256-3,		"… … all other elements nil");
		ok(next['i'].n == nil,                  "… … n nil [i]");
		ok(next['o'].n == nil,                  "… … n nil [o]");
		ok(next['p'].n == nil,                  "… … n nil [p]");
		eq(string next['i'].tail, "te",		"… … tail [i]");
		eq(string next['o'].tail, "urce",	"… … tail [o]");
		eq(string next['p'].tail, "ort",	"… … tail [p]");
		eq_int(next['i'].id, F_SITE,		"… … id [i]");
		eq_int(next['o'].id, F_SOURCE,		"… … id [o]");
		eq_int(next['p'].id, F_SPORT,		"… … id [p]");
	'v' =>	ok(K2ID[i] != nil,			"[v] not nil");
		ok(K2ID[i].n == nil,			"… n nil");
		eq(string K2ID[i].tail, "alue",		"… tail");
		eq_int(K2ID[i].id, F_VALUE,		"… id");
	'x' =>	ok(K2ID[i] != nil,                      "[x] not nil");
		ok(K2ID[i].n != nil,			"… n not nil");
		ok(K2ID[i].tail == nil,			"… tail");
		eq_int(K2ID[i].id, F_X,			"… id");
		next := K2ID[i].n;
		nextnulls := 0;
		ok(next['2'] != nil,			"… … [2] not nil");
		for(j := 0; j < len next; j++)
			if(next[j] == nil)
				nextnulls++;
		eq_int(nextnulls, 256-1,		"… … all other elements nil");
		ok(next['2'].n == nil,			"… … n nil");
		ok(next['2'].tail == nil,		"… … tail");
		eq_int(next['2'].id, F_X2,		"… … id");
	* =>	if (K2ID[i] == nil)
			nulls++;
	}
	eq_int(nulls, 256-9, "all other elements nil");

}

