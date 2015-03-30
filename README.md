**CJSON** is Limbo module for OS Inferno, implemented in C for speed. It works as JSON tokenizer, allowing you to load data from JSON into your custom adt and generate JSON using data from your adt.

# Install #

Tested only on Linux.

## Gentoo Linux ##

Add overlay "powerman" (using layman tool) and install _dev-inferno/inferno_ (with USE flag "cjson" enabled).

## Using `hg clone` ##

```
cd $INFERNO_ROOT
hg clone https://inferno-cjson.googlecode.com/hg/ tmp/inferno-cjson
cp -a tmp/inferno-cjson/* ./
rm -rf tmp/inferno-cjson
./patch.cjson
```

# Examples #

```
Struct: adt{
        str: string;
        r:   real;
        opt: int;
        arr: list of int;
};

F_STR, F_REAL, F_OPT, F_ARR: con iota;

        keys := cjson->makekeys(array[] of {
                F_STR   => "str",
                F_REAL  => "real",
                F_OPT   => "opt",
                F_ARR   => "arr",
        });

        struct := ref Struct;

### Parsing

        t := JSON2Token.new(array of byte "{\"real\": -2.3e2, \"arr\":[10,20]}");

        t.obj();
OBJ:    for(;;) case t.getkey(keys) {
        END_OBJ =>      break OBJ;
        UNK_KEY =>      t.skip();
        F_STR =>        struct.str = t.gets();
        F_REAL =>       struct.r = t.getr();
        F_OPT =>        if(!t.getnull())
                                struct.opt = t.getn();
        F_ARR =>        t.arr();
                        while(!t.close())
                                struct.arr = t.getn() :: struct.arr;
        }
        t.close();
        t.end();

### Generating

        json := Token2JSON.new(128)
                .obj()
                .key(keys, F_STR)       .str(struct.str)
                .key(keys, F_REAL)      .realnum(struct.r)
                .key(keys, F_OPT)       .num(struct.opt)
                .key(keys, F_ARR)       .arr();
        for(l := struct.arr; l != nil; l = tl l)
                json                    .num(hd l);
        json                            .close()
                .close();

        text := string json.encode();
```