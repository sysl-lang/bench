// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// Contributed by Jeremy Zerfas
//
// Tuned for this suite. The counting is the same: every k-mer of the third
// sequence put into a khash table keyed by its 2k-bit code, with the same
// `key ^ key >> 7` hash. What is faster:
// - k-mers of up to 16 bases are counted in a table with 32-bit keys (eight
//   bytes per slot instead of sixteen); only the 18-mers need 64-bit keys;
// - every table is sized once up front (kh_resize, a capacity hint) so it
//   never rehashes while counting;
// - standard input is read whole with read(2), and the sequence lines are
//   joined and encoded in one pass.
// Single-threaded: the seven counts run one after another.

#define MAXIMUM_OUTPUT_LENGTH 4096

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <khash.h>

#define CUSTOM_HASH_FUNCTION(key) ((key) ^ (key)>>7)

KHASH_INIT(kmer64, uint64_t, uint32_t, 1, CUSTOM_HASH_FUNCTION, kh_int64_hash_equal)
KHASH_INIT(kmer32, uint32_t, uint32_t, 1, CUSTOM_HASH_FUNCTION, kh_int_hash_equal)

typedef intptr_t intnative_t;

typedef struct {
	uint64_t	key;
	uint32_t	value;
} element;

#define code_For_Nucleotide(nucleotide) (" \0 \1\3  \2"[nucleotide & 0x7])
#define nucleotide_For_Code(code) ("ACGT"[code & 0x3])

// A capacity hint: enough slots that the table stays under khash's load
// limit for every k-mer the sequence can hold, capped where it no longer
// matters (larger tables only cost cache).
static khint_t capacity_For(intnative_t length, intnative_t k){
	uint64_t distinct = k < 16 ? (uint64_t)1 << 2*k : UINT64_MAX;
	if(distinct > (uint64_t)length) distinct = length;
	if(distinct > (1u << 20)) distinct = 1u << 20;
	return (khint_t)(distinct * 4 / 3 + 16);
}

static int element_Compare(const element * const left_Element
  , const element * const right_Element){
	if(left_Element->value < right_Element->value) return 1;
	if(left_Element->value > right_Element->value) return -1;
	return left_Element->key > right_Element->key ? 1 : -1;
}

// Counts every k-mer of length k into a table of the given key type, then
// runs the trailing statement on it. The table is h, the key type K.
#define COUNT(NAME, K, poly, len, k, ...) do{ \
	khash_t(NAME) * h=kh_init(NAME); \
	kh_resize(NAME, h, capacity_For(len, k)); \
	K key=0; \
	const K mask=(K)(((uint64_t)1<<2*(k))-1); \
	for(intnative_t i=0; i<(k)-1; i++) key=(key<<2 & mask) | (poly)[i]; \
	for(intnative_t i=(k)-1; i<(len); i++){ \
		key=(key<<2 & mask) | (poly)[i]; \
		int unused; \
		const khiter_t it=kh_put(NAME, h, key, &unused); \
		if(unused) kh_value(h, it)=1; else kh_value(h, it)++; \
	} \
	__VA_ARGS__; \
	kh_destroy(NAME, h); \
}while(0)

static void frequencies(const char * const poly, const intnative_t len
  , const intnative_t k, char * const output){
	element * elements=NULL;
	intnative_t n=0;
	COUNT(kmer32, uint32_t, poly, len, k, {
		elements=malloc(kh_size(h)*sizeof(element));
		uint32_t key2, value;
		kh_foreach(h, key2, value, elements[n++]=((element){key2, value}));
	});

	qsort(elements, n, sizeof(element)
	  , (int (*)(const void *, const void *)) element_Compare);

	for(intnative_t output_Position=0, i=0; i<n; i++){
		char oligonucleotide[k+1];
		for(intnative_t j=k-1; j>-1; j--){
			oligonucleotide[j]=nucleotide_For_Code(elements[i].key);
			elements[i].key>>=2;
		}
		oligonucleotide[k]='\0';
		output_Position+=snprintf(output+output_Position
		  , MAXIMUM_OUTPUT_LENGTH-output_Position, "%s %.3f\n", oligonucleotide
		  , 100.0f*elements[i].value/(len-k+1));
	}
	free(elements);
}

static void count_Of(const char * const poly, const intnative_t len
  , const char * const oligonucleotide, char * const output){
	const intnative_t k=strlen(oligonucleotide);
	uint64_t want=0;
	for(intnative_t i=0; i<k; i++)
		want=(want<<2) | code_For_Nucleotide(oligonucleotide[i]);
	uintmax_t count=0;
	if(k<=16){
		COUNT(kmer32, uint32_t, poly, len, k, {
			khiter_t it=kh_get(kmer32, h, (uint32_t)want);
			count=it==kh_end(h) ? 0 : kh_value(h, it);
		});
	}else{
		COUNT(kmer64, uint64_t, poly, len, k, {
			khiter_t it=kh_get(kmer64, h, want);
			count=it==kh_end(h) ? 0 : kh_value(h, it);
		});
	}
	snprintf(output, MAXIMUM_OUTPUT_LENGTH, "%ju\t%s", count, oligonucleotide);
}

int main(){
	size_t cap=1<<24, n=0;
	char * in=malloc(cap);
	for(;;){
		if(n==cap) in=realloc(in, cap*=2);
		ssize_t r=read(0, in+n, cap-n);
		if(r<=0) break;
		n+=r;
	}

	// Find the line after ">THREE" and encode every base up to the next '>'.
	char * p=in, * const end=in+n;
	while(p<end && !(p[0]=='>' && end-p>=6 && !memcmp(p, ">THREE", 6))){
		char * nl=memchr(p, '\n', end-p);
		p=nl ? nl+1 : end;
	}
	char * nl=p<end ? memchr(p, '\n', end-p) : NULL;
	p=nl ? nl+1 : end;

	char * poly=malloc(end-p+1);
	intnative_t len=0;
	for(; p<end && *p!='>'; p++)
		if(*p!='\n') poly[len++]=code_For_Nucleotide(*p);

	char output_Buffer[7][MAXIMUM_OUTPUT_LENGTH];
	frequencies(poly, len, 1, output_Buffer[0]);
	frequencies(poly, len, 2, output_Buffer[1]);
	count_Of(poly, len, "GGT", output_Buffer[2]);
	count_Of(poly, len, "GGTA", output_Buffer[3]);
	count_Of(poly, len, "GGTATT", output_Buffer[4]);
	count_Of(poly, len, "GGTATTTTAATT", output_Buffer[5]);
	count_Of(poly, len, "GGTATTTTAATTTATAGT", output_Buffer[6]);

	for(intnative_t i=0; i<7; printf("%s\n", output_Buffer[i++]));
	return 0;
}
