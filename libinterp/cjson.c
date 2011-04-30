#include <lib9.h>
#include <isa.h>
#include <interp.h>
#include "runt.h"
#include "raise.h"
#include "cjsonmod.h"

static char exDupKey[]			= "duplicate keys";
static char exNilKeys[]			= "prepare keys with makekeys() first";
static char exTokenEOF[]		= "unexpected EOF";
static char exStack[]			= "stack overflow";
static char exStackNotEnd[]		= "not end of current object/array";
static char exTokenExpectObj[]		= "expected '{'";
static char exTokenExpectArr[]		= "expected '['";
static char exTokenExpectStr[]		= "expected '\"'";
static char exTokenNonTerminatedStr[]	= "non-terminated string";
static char exTokenExpectColon[]	= "expected ':'";
static char exTokenExpectBool[]		= "expected true or false";
static char exTokenBadUnicode[]		= "bad \\u in string";
static char exTokenExpectNumber[]	= "expected number";
static char exTokenExpectEOF[]		= "expected EOF";
static char exTokenExpectToken[]	= "expected json token";
static char exJSONIncomplete[]		= "incomplete json";

static Type* TJSON2Token;
static Type* TToken2JSON;
static Type* TNode;
static Type* TKeys;
static uchar JSON2Token_map[]		= CJSON_JSON2Token_map;
static uchar Token2JSON_map[]		= CJSON_Token2JSON_map;
static uchar Node_map[]			= CJSON_Node_map;
static uchar Keys_map[]			= CJSON_Keys_map;

#define SKIPSP()				\
	for(; t->pos < buflen; t->pos++)	\
		if(buf[t->pos] != ' ' && buf[t->pos] != '\t' && buf[t->pos] != '\n') \
			break;

void
cjsonmodinit(void)
{
	builtinmod("$CJSON", CJSONmodtab, CJSONmodlen);

	TJSON2Token = dtype(freeheap, CJSON_JSON2Token_size, JSON2Token_map, sizeof(JSON2Token_map));
	TToken2JSON = dtype(freeheap, CJSON_Token2JSON_size, Token2JSON_map, sizeof(Token2JSON_map));
	TNode = dtype(freeheap, CJSON_Node_size, Node_map, sizeof(Node_map));
	TKeys = dtype(freeheap, CJSON_Keys_size, Keys_map, sizeof(Keys_map));
}

static Array*
slice(Array* sa, int s, int e)
{
        Type *t;
        Heap *h;
        Array *a;

	if(s < 0 || s > e || e > sa->len)
		error(exBounds);

        t = sa->t;
        h = heap(&Tarray);
        a = H2D(Array*, h);
        a->len = e - s;
        a->data = sa->data + s*t->size;
        a->t = t;
        t->ref++;

        if(sa->root != H)                       /* slicing a slice */
                sa = sa->root;

        a->root = sa;
        h = D2H(sa);
        h->ref++;
        Setmark(h);

        return a;
}

static uchar*
quote(uchar *s, int *qlen)
{
	uchar *q, *sp, *qp;
	int prefixlen, len, h;

	for(sp = s; *sp != '\0'; sp++)
		if(*sp < 0x20 || *sp == '"' || *sp == '\\' || *sp == '/')
			break;
	
	if(*sp == '\0'){
		*qlen = sp - s;
		q = malloc(*qlen + 1);
		memmove(q, s, *qlen + 1);
		return q;
	}

	prefixlen = len = sp - s;
	for(; *sp != '\0'; sp++)
		if(*sp < 0x20)
			len += 6;
		else if(*sp == '"' || *sp == '\\' || *sp == '/')
			len += 2;
		else
			len++;

	*qlen = len;
	q = malloc(*qlen + 1);
	memmove(q, s, prefixlen);

	for(sp = s+prefixlen, qp = q+prefixlen; *sp != '\0'; sp++)
		switch(*sp){
		default:
			if(*sp >= 0x20)
				*qp++ = *sp;
			else{
				*qp++ = '\\';
				*qp++ = 'u';
				*qp++ = '0';
				*qp++ = '0';
				h = (*sp >> 4) & 0xF;
				if(h <= 9)	*qp++ = h + '0';
				else		*qp++ = h + 'a';
				h = (*sp) & 0xF;
				if(h <= 9)	*qp++ = h + '0';
				else		*qp++ = h + 'a';
			}
			break;
		case '"':
			*qp++ = '\\';
			*qp++ = '"';
			break;
		case '\\':
			*qp++ = '\\';
			*qp++ = '\\';
			break;
		case '/':
			*qp++ = '\\';
			*qp++ = '/';
			break;
		case '\n':
			*qp++ = '\\';
			*qp++ = 'n';
			break;
		case '\t':
			*qp++ = '\\';
			*qp++ = 't';
			break;
		case '\r':
			*qp++ = '\\';
			*qp++ = 'r';
			break;
		case '\b':
			*qp++ = '\\';
			*qp++ = 'b';
			break;
		case '\f':
			*qp++ = '\\';
			*qp++ = 'f';
			break;
		}
	*qp = '\0';
	return q;
}

static void
extendbuf(CJSON_Token2JSON *j)
{
	Array *new;

	new = H2D(Array*, heaparray(&Tbyte, 2 * j->buf->len));
	memmove(new->data, j->buf->data, j->size);
	destroy(j->buf);
	j->buf = new;
}

void
CJSON_makekeys(void *fp)
{
	F_CJSON_makekeys *f;
	Array *a;
	void *tmp;
	Array *id2key, *key2id, *k;
	int i, j;
	uchar *b, c;
	int blen;
	String **adata;
	Array **idata;
	CJSON_Node **kdata, **ndata;
	CJSON_Node *n, *n2;
	CJSON_Keys *keys;

	f = fp;
	a = f->a;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);
	adata = (String**)a->data;

	id2key = H2D(Array*, heaparray(&Tptr, a->len));
	key2id = H2D(Array*, heaparray(&Tptr, 256));
	idata  = (Array**)id2key->data;

	for(i = 0; i < a->len; i++){
		b = quote(string2c(adata[i]), &blen);
		if(blen == 0){
			free(b);
			continue;
		}
		idata[i] = H2D(Array*, heaparray(&Tbyte, blen));
		memmove(idata[i]->data, b, blen);
		free(b);
		b = idata[i]->data;	// no \0 at end anymore

		k = key2id;
		for(j = 0; j < blen; j++){
			c = b[j];
			kdata = (CJSON_Node**)k->data;
			n = kdata[c];
			if(n == H){
				n = kdata[c] = H2D(CJSON_Node*, heap(TNode));
				n->id = i;
				if(j + 1 < blen){
					n->tail = H2D(Array*, heaparray(&Tbyte, blen-(j+1)));
					memmove(n->tail->data, b+j+1, n->tail->len);
				}
				break;
			}
			if(n->n == H){
				n->n = H2D(Array*, heaparray(&Tptr, 256));
				if(n->tail != H){
					c = n->tail->data[0];
					ndata = (CJSON_Node**)n->n->data;
					n2 = ndata[c] = H2D(CJSON_Node*, heap(TNode));
					n2->id = n->id;
					if(n->tail->len > 1)
						n2->tail = slice(n->tail, 1, n->tail->len);
					n->id = CJSON_UNK_KEY;
					destroy(n->tail);
					n->tail = H;
				}
			}
			if(j + 1 == blen && n->tail == H){
				if(n->id != CJSON_UNK_KEY)
					error(exDupKey);
				n->id = i;
				break;
			}
			k = n->n;
		}
	}

	keys = H2D(CJSON_Keys*, heap(TKeys));
	keys->id2key = id2key;
	keys->key2id = key2id;
	*f->ret = keys;
}

void
JSON2Token_new(void *fp)
{
	F_JSON2Token_new *f;
	Array *a;
	void *tmp;
	CJSON_JSON2Token *t;
	Heap *h;
	uchar *buf;
	int buflen;

	f = fp;
	a = f->a;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	t = H2D(CJSON_JSON2Token*, heap(TJSON2Token));
	t->buf = a;
	h = D2H(a);
	h->ref++;
	Setmark(h);
	t->pos = 0;
	t->stack = H2D(Array*, heaparray(&Tbyte, 16));
	t->depth = 0;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	SKIPSP();

	*f->ret = t;
}

void
JSON2Token_obj(void *fp)
{
	F_JSON2Token_obj *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != '{')
		error(exTokenExpectObj);
	
	t->pos++;

	if(t->depth == t->stack->len)
		error(exStack);
	t->stack->data[t->depth++] = '}';

	SKIPSP();
}

void
JSON2Token_arr(void *fp)
{
	F_JSON2Token_arr *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != '[')
		error(exTokenExpectArr);
	
	t->pos++;

	if(t->depth == t->stack->len)
		error(exStack);
	t->stack->data[t->depth++] = ']';

	SKIPSP();
}

void
JSON2Token_close(void *fp)
{
	F_JSON2Token_close *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	if(t->depth != 0 && t->stack->data[t->depth - 1] == buf[t->pos])
		--t->depth;
	else{
		if(t->depth == 0 || t->stack->data[t->depth - 1] == '}')
			error(exStackNotEnd);
		*f->ret = 0;
		return;
	}

	t->pos++;

	SKIPSP();
	if(t->pos != buflen && buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	*f->ret = 1;
}

void
JSON2Token_getkey(void *fp)
{
	F_JSON2Token_getkey *f;
	CJSON_JSON2Token *t;
	Array *k;
	uchar *buf;
	int buflen;
	int s, l;
	int i, j, lt;
	CJSON_Node *n;

	f = fp;
	t = f->t;
	if(f->k == H)
		error(exNilKeys);
	k = f->k->key2id;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] == '}'){
		*f->ret = CJSON_END_OBJ;
		return;
	}
	if(buf[t->pos] != '"')
		error(exTokenExpectStr);

	t->pos++;
	s = t->pos;
	for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
		if(buf[t->pos] == '\\')
			t->pos++;	// keys not unquoted for speed
	if(t->pos >= buflen)
		error(exTokenNonTerminatedStr);
	l = t->pos - s;
	t->pos++;

	SKIPSP();
	
	if(buf[t->pos] != ':')
		error(exTokenExpectColon);
	t->pos++;

	SKIPSP();

	for(i = 0; i < l; i++){
		n = ((CJSON_Node**)k->data)[ buf[s+i] ];
		if(n == H)
			goto UNK_KEY;
		if(n->n == H || i == l - 1){
			lt = n->tail == H ? 0 : n->tail->len;
			if(l - i - 1 != lt)
				goto UNK_KEY;
			for(j = 0; j < lt; j++){
				if(buf[s+i+1+j] != n->tail->data[j])
					goto UNK_KEY;
			}
			*f->ret = n->id; // n.id may be UNK_KEY when n.tail==nil
			return;
		}
		k = n->n;
	}

UNK_KEY:
	*f->ret = CJSON_UNK_KEY;
}

void
JSON2Token_getnull(void *fp)
{
	F_JSON2Token_getnull *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen){
		*f->ret = 0;
		return;
	}

	if(buf[t->pos] == 'n'){
		t->pos += 4;
	
		if(t->pos > buflen)
			error(exTokenEOF);

		SKIPSP();
		if(t->pos != buflen && buf[t->pos] == ','){
			t->pos++;
			SKIPSP();
		}

		*f->ret = 1;
		return;
	}

	*f->ret = 0;
}

void
JSON2Token_getbool(void *fp)
{
	F_JSON2Token_getbool *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	if(buf[t->pos] == 't'){
		t->pos += 4;
	
		if(t->pos > buflen)
			error(exTokenEOF);

		SKIPSP();
		if(t->pos != buflen && buf[t->pos] == ','){
			t->pos++;
			SKIPSP();
		}

		*f->ret = 1;
		return;
	}

	if(buf[t->pos] == 'f'){
		t->pos += 5;
	
		if(t->pos > buflen)
			error(exTokenEOF);

		SKIPSP();
		if(t->pos != buflen && buf[t->pos] == ','){
			t->pos++;
			SKIPSP();
		}

		*f->ret = 0;
		return;
	}

	error(exTokenExpectBool);
}

void
JSON2Token_gets(void *fp)
{
	F_JSON2Token_gets *f;
	CJSON_JSON2Token *t;
	void *tmp;
	uchar *buf;
	int buflen;
	int s, l;
	int quote_pos;
	uchar *str;
	int i;
	uchar h;
	Rune c;

	f = fp;
	t = f->t;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);
	if(buf[t->pos] != '"')
		error(exTokenExpectStr);

	quote_pos = 0;
	t->pos++;
	s = t->pos;
	for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
		if(buf[t->pos] == '\\')
			if(quote_pos == 0)
				quote_pos = t->pos++;
			else
				t->pos++;
	if(t->pos >= buflen)
		error(exTokenNonTerminatedStr);
	l = t->pos - s;
	t->pos++;

	SKIPSP();

	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	if(quote_pos == 0){
		*f->ret = c2string(buf+s, l);
		return;
	}

	str = malloc(l);
	if(str == nil)
		error(exNomem);
	buflen = s + l;
	l = 0;
        // buflen        now cut buf at end of string (point to closing ")
        // l             real length of str
        // s             start pos in buf of next chunk to copy to str
        // quote_pos     end   pos in buf of next chunk to copy to str (point to next \)
	for(;;){
		memmove(str+l, buf+s, quote_pos - s);
		l += quote_pos - s;
		switch(buf[quote_pos+1]){
		default:
			str[l++] = buf[quote_pos+1];
			s = quote_pos + 2;
			break;
		case 'b':
			str[l++] = '\b';
			s = quote_pos + 2;
			break;
		case 'f':
			str[l++] = '\f';
			s = quote_pos + 2;
			break;
		case 'n':
			str[l++] = '\n';
			s = quote_pos + 2;
			break;
		case 'r':
			str[l++] = '\r';
			s = quote_pos + 2;
			break;
		case 't':
			str[l++] = '\t';
			s = quote_pos + 2;
			break;
		case 'u':
			s = quote_pos + 6;
			if(s > buflen){
				free(str);
				error(exTokenBadUnicode);
			}
			c = 0;
			for(i = 0; i < 4; i++){
				h = buf[quote_pos+2+i];
				if('0' <= h && h <= '9')
					c = (c<<4) | (h-'0');
				else if('a' <= h && h <= 'f')
					c = (c<<4) | (10+(h-'a'));
				else if('A' <= h && h <= 'F')
					c = (c<<4) | (10+(h-'A'));
				else{
					free(str);
					error(exTokenBadUnicode);
				}
			}
			l += runetochar(str+l, &c);
		}
		for(quote_pos = s; buf[quote_pos] != '\\'; quote_pos++)
			if(quote_pos == buflen){
				memmove(str+l, buf+s, quote_pos - s);
				l += quote_pos - s;
				*f->ret = c2string(str, l);
				free(str);
				return;
			}
	}
}

void
JSON2Token_getr(void *fp)
{
	F_JSON2Token_getr *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;
	int is_str;
	double d;
	char *s, *e;
	int l;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	is_str = 0;
	if(buf[t->pos] == '"'){
		t->pos++;
		is_str = 1;
	}

	l = buflen - t->pos;
	s = malloc(l + 1);
	if(s == nil)
		error(exNomem);
	memmove(s, buf+t->pos, l);
	s[l] = 0;

	d = strtod(s, &e);
	l = e - s;
	free(s);
	if(l <= 0)
		error(exTokenExpectNumber);
	t->pos += l;

	if(is_str)
		if(buf[t->pos] == '"')
			t->pos++;
		else
			error(exTokenNonTerminatedStr);
	
	SKIPSP();

	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	*f->ret = d;
}

void
JSON2Token_getn(void *fp)
{
	F_JSON2Token_getn *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;
	int is_str;
	int n;
	char *s, *e;
	int l;

	f = fp;
	t = f->t;

	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	is_str = 0;
	if(buf[t->pos] == '"'){
		t->pos++;
		is_str = 1;
	}

	l = buflen - t->pos;
	s = malloc(l + 1);
	if(s == nil)
		error(exNomem);
	memmove(s, buf+t->pos, l);
	s[l] = 0;

	n = strtol(s, &e, 10);
	l = e - s;
	free(s);
	if(l <= 0)
		error(exTokenExpectNumber);
	t->pos += l;

	if(is_str)
		if(buf[t->pos] == '"')
			t->pos++;
		else
			error(exTokenNonTerminatedStr);
	
	SKIPSP();

	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}

	*f->ret = n;
}

void
JSON2Token_skip(void *fp)
{
	F_JSON2Token_gets *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;
	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		error(exTokenEOF);

	if(buf[t->pos] == '"'){
		t->pos++;
		for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
			if(buf[t->pos] == '\\')
				t->pos++;
		if(t->pos >= buflen)
			error(exTokenNonTerminatedStr);
		t->pos++;
	}
	else if(buf[t->pos] == '-' || ('0' <= buf[t->pos] && buf[t->pos] <= '9')){
		t->pos++;
		while(t->pos < buflen && ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
			t->pos++;
		if(t->pos < buflen && buf[t->pos] == '.'){
			t->pos++;
			while(t->pos < buflen && ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
				t->pos++;
		}
		if(t->pos < buflen && (buf[t->pos] == 'e' || buf[t->pos] == 'E')){
			t->pos++;
			if(buf[t->pos] == '+' || buf[t->pos] == '-')
				t->pos++;
			while(t->pos < buflen && ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
				t->pos++;
		}
	}
	else if(buf[t->pos] == 't')
		t->pos += 4;
	else if(buf[t->pos] == 'f')
		t->pos += 5;
	else if(buf[t->pos] == 'n')
		t->pos += 4;
	else if(buf[t->pos] == '['){
		t->pos++;

		SKIPSP();

		while(t->pos < buflen && buf[t->pos] != ']')
			JSON2Token_skip(fp);
		if(t->pos >= buflen)
			error(exTokenEOF);
		t->pos++;
	}
	else if(buf[t->pos] == '{'){
		t->pos++;

		SKIPSP();

		while(t->pos < buflen && buf[t->pos] != '}'){
			if(buf[t->pos] != '"')
				error(exTokenExpectStr);

			t->pos++;
			for(; t->pos < buflen && buf[t->pos] != '"'; t->pos++)
				if(buf[t->pos] == '\\')
					t->pos++;
			if(t->pos >= buflen)
				error(exTokenNonTerminatedStr);
			t->pos++;

			SKIPSP();
			
			if(buf[t->pos] != ':')
				error(exTokenExpectColon);
			t->pos++;

			SKIPSP();

			JSON2Token_skip(fp);
		}
		if(t->pos >= buflen)
			error(exTokenEOF);
		t->pos++;
	}
	else
		error(exTokenExpectToken);

	SKIPSP();
	
	if(buf[t->pos] == ','){
		t->pos++;
		SKIPSP();
	}
}

void
JSON2Token_gettype(void *fp)
{
	F_JSON2Token_gettype *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;
	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos >= buflen)
		*f->ret = 0;
	else if(buf[t->pos] == '"')
		*f->ret = '"';
	else if(buf[t->pos] == '-' || ('0' <= buf[t->pos] && buf[t->pos] <= '9'))
		*f->ret = '0';
	else if(buf[t->pos] == '{')
		*f->ret = '{';
	else if(buf[t->pos] == '}')
		*f->ret = '}';
	else if(buf[t->pos] == '[')
		*f->ret = '[';
	else if(buf[t->pos] == ']')
		*f->ret = ']';
	else if(buf[t->pos] == 't')
		*f->ret = 't';
	else if(buf[t->pos] == 'f')
		*f->ret = 'f';
	else if(buf[t->pos] == 'n')
		*f->ret = 'n';
	else
		*f->ret = -1;
}

void
JSON2Token_end(void *fp)
{
	F_JSON2Token_end *f;
	CJSON_JSON2Token *t;
	uchar *buf;
	int buflen;

	f = fp;
	t = f->t;
	buf = (uchar*)t->buf->data;
	buflen = t->buf->len;

	if(t->pos != buflen)
		error(exTokenExpectEOF);
}

void
Token2JSON_new(void *fp)
{
	F_Token2JSON_new *f;
	int sizehint;
	void *tmp;
	CJSON_Token2JSON *j;

	f = fp;
	sizehint = f->sizehint;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	if(sizehint < 16)
		sizehint = 16;

	j = H2D(CJSON_Token2JSON*, heap(TToken2JSON));
	j->buf   = H2D(Array*, heaparray(&Tbyte, sizehint));
	j->size  = 0;
	j->stack = H2D(Array*, heaparray(&Tbyte, 16));
	j->depth = 0;

	*f->ret = j;
}

void
Token2JSON_obj(void *fp)
{
	F_Token2JSON_obj *f;
	void *tmp;
	CJSON_Token2JSON *j;
	Heap *h;

	f = fp;
	j = f->j;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	if(j->depth == j->stack->len)
		error(exStack);
	j->stack->data[j->depth++] = '}';

	if(j->buf->len - j->size < 1)
		extendbuf(j);
	
	j->buf->data[j->size++] = '{';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_arr(void *fp)
{
	F_Token2JSON_arr *f;
	void *tmp;
	CJSON_Token2JSON *j;
	Heap *h;

	f = fp;
	j = f->j;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	if(j->depth == j->stack->len)
		error(exStack);
	j->stack->data[j->depth++] = ']';

	if(j->buf->len - j->size < 1)
		extendbuf(j);
	
	j->buf->data[j->size++] = '[';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_close(void *fp)
{
	F_Token2JSON_close *f;
	void *tmp;
	CJSON_Token2JSON *j;
	Heap *h;

	f = fp;
	j = f->j;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	if(j->depth == 0)
		error(exStack);

	if(j->size > 0 && j->buf->data[j->size - 1] == ',')
		j->size--;

	if(j->buf->len - j->size < 2)
		extendbuf(j);
	
	j->buf->data[j->size++] = j->stack->data[--j->depth];
	j->buf->data[j->size++] = ',';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_key(void *fp)
{
	F_Token2JSON_key *f;
	void *tmp;
	CJSON_Token2JSON *j;
	Array *k;
	int id;
	Array *key;
	Heap *h;

	f = fp;
	j = f->j;
	if(f->k == H)
		error(exNilKeys);
	k = f->k->id2key;
	id= f->id;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	if(!(0 <= id && id < k->len))
		error(exBounds);
	key = ((Array**)k->data)[id];

	while(j->buf->len - j->size < 3 + key->len)
		extendbuf(j);
	
	j->buf->data[j->size++] = '"';
	memmove(j->buf->data + j->size, key->data, key->len);
	j->size += key->len;
	j->buf->data[j->size++] = '"';
	j->buf->data[j->size++] = ':';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_str(void *fp)
{
	F_Token2JSON_str *f;
	void *tmp;
	CJSON_Token2JSON *j;
	String *s;
	uchar *q;
	int qlen;
	Heap *h;

	f = fp;
	j = f->j;
	s = f->s;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	q = quote(string2c(s), &qlen);

	while(j->buf->len - j->size < 3 + qlen)
		extendbuf(j);
	
	j->buf->data[j->size++] = '"';
	memmove(j->buf->data + j->size, q, qlen);
	j->size += qlen;
	j->buf->data[j->size++] = '"';
	j->buf->data[j->size++] = ',';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_num(void *fp)
{
	F_Token2JSON_num *f;
	void *tmp;
	CJSON_Token2JSON *j;
	int n;
	Heap *h;

	f = fp;
	j = f->j;
	n = f->n;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	while(j->buf->len - j->size < 1 + 16)
		extendbuf(j);
	
	j->size += sprint(j->buf->data + j->size, "%d", n);
	j->buf->data[j->size++] = ',';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_bignum(void *fp)
{
	F_Token2JSON_bignum *f;
	void *tmp;
	CJSON_Token2JSON *j;
	long n;
	Heap *h;

	f = fp;
	j = f->j;
	n = f->n;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	while(j->buf->len - j->size < 1 + 16)
		extendbuf(j);
	
	j->size += sprint(j->buf->data + j->size, "%lld", n);
	j->buf->data[j->size++] = ',';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_realnum(void *fp)
{
	F_Token2JSON_realnum *f;
	void *tmp;
	CJSON_Token2JSON *j;
	double n;
	Heap *h;

	f = fp;
	j = f->j;
	n = f->n;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	while(j->buf->len - j->size < 1 + 32)
		extendbuf(j);
	
	j->size += sprint(j->buf->data + j->size, "%g", n);
	j->buf->data[j->size++] = ',';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_bool(void *fp)
{
	F_Token2JSON_bool *f;
	void *tmp;
	CJSON_Token2JSON *j;
	int n;
	Heap *h;

	f = fp;
	j = f->j;
	n = f->n;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	while(j->buf->len - j->size < 1 + 5)
		extendbuf(j);
	
	if(n == 0){
		j->buf->data[j->size++] = 'f';
		j->buf->data[j->size++] = 'a';
		j->buf->data[j->size++] = 'l';
		j->buf->data[j->size++] = 's';
		j->buf->data[j->size++] = 'e';
	}else{
		j->buf->data[j->size++] = 't';
		j->buf->data[j->size++] = 'r';
		j->buf->data[j->size++] = 'u';
		j->buf->data[j->size++] = 'e';
	}
	j->buf->data[j->size++] = ',';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_null(void *fp)
{
	F_Token2JSON_bool *f;
	void *tmp;
	CJSON_Token2JSON *j;
	Heap *h;

	f = fp;
	j = f->j;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	while(j->buf->len - j->size < 1 + 4)
		extendbuf(j);
	
	j->buf->data[j->size++] = 'n';
	j->buf->data[j->size++] = 'u';
	j->buf->data[j->size++] = 'l';
	j->buf->data[j->size++] = 'l';
	j->buf->data[j->size++] = ',';

        h = D2H(j);
        h->ref++;
        Setmark(h);
	*f->ret = j;
}

void
Token2JSON_encode(void *fp)
{
	F_Token2JSON_encode *f;
	void *tmp;
	CJSON_Token2JSON *j;
	int n;

	f = fp;
	j = f->j;
	tmp = *f->ret;
	*f->ret = H;
	destroy(tmp);

	if(j->depth != 0)
		error(exJSONIncomplete);

	n = j->size;
	if(j->size > 0 && j->buf->data[j->size - 1] == ',')
		n--;

	*f->ret = slice(j->buf, 0, n);
}

