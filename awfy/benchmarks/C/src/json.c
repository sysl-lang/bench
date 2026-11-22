#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "benchmark.h"
#include "som/error.h"
#include "som/vector.h"

// json.h of the C++ port. The document is C++'s literal, json.h lines 13-451,
// byte for byte (scripts/check-upstream.zsh compares them).
static const char rap_benchmark_minified[] =
#include "json_data.inc"

// ---- String: an owned std::string, its bytes and its length.

typedef struct String {
  char* data;
  size_t len;
} String;

// `std::string(s, start, n)`: a copy of n bytes, NUL-terminated as
// std::string's storage is.
static String String_copy(const char* s, size_t n) {
  String str = {(char*)malloc(n + 1), n};
  memcpy(str.data, s, n);
  str.data[n] = '\0';
  return str;
}

static bool String_equals(String a, const char* b, size_t b_len) {
  return a.len == b_len && memcmp(a.data, b, b_len) == 0;
}

// A growable std::string used as a buffer: `+=` appends, `= ""` empties it and
// keeps its storage.
typedef struct StringBuffer {
  char* data;
  size_t len;
  size_t capacity;
} StringBuffer;

static void StringBuffer_append(StringBuffer* self, const char* s, size_t n) {
  if (self->len + n > self->capacity) {
    size_t new_capacity = self->capacity == 0 ? 16 : self->capacity * 2;
    while (new_capacity < self->len + n) {
      new_capacity *= 2;
    }
    self->data = (char*)realloc(self->data, new_capacity);
    self->capacity = new_capacity;
  }
  memcpy(self->data + self->len, s, n);
  self->len += n;
}

DEFINE_VECTOR(StringVector, String)

// ---- HashIndexTable

typedef struct HashIndexTable {
  int32_t hash_table[32];
} HashIndexTable;

static int32_t HashIndexTable_string_hash(const HashIndexTable* self,
                                          size_t len) {
  (void)self;
  // this is not a proper hash, but sufficient for the benchmark,
  // and very portable!
  return (int32_t)len * 1402589;
}

static int32_t HashIndexTable_hash_slot_for(const HashIndexTable* self,
                                            size_t len) {
  const int32_t size =
      (int32_t)(sizeof(self->hash_table) / sizeof(self->hash_table[0]));
  return HashIndexTable_string_hash(self, len) & (size - 1);
}

static void HashIndexTable_add(HashIndexTable* self, String name,
                               int32_t index) {
  const int32_t slot = HashIndexTable_hash_slot_for(self, name.len);
  if (index < 0xff) {
    // increment by 1, 0 stands for empty
    self->hash_table[slot] = (index + 1) & 0xff;
  } else {
    self->hash_table[slot] = 0;
  }
}

static int32_t HashIndexTable_get(const HashIndexTable* self, size_t len) {
  const int32_t slot = HashIndexTable_hash_slot_for(self, len);
  // subtract 1, 0 stands for empty
  return (self->hash_table[slot] & 0xff) - 1;
}

// ---- JsonValue: the base class, all of whose members are virtual.

typedef struct JsonValue JsonValue;
typedef struct JsonArray JsonArray;
typedef struct JsonObject JsonObject;

typedef struct JsonValueVtbl {
  void (*destroy)(JsonValue* self);
  bool (*is_object)(const JsonValue* self);
  bool (*is_array)(const JsonValue* self);
  bool (*is_number)(const JsonValue* self);
  bool (*is_string)(const JsonValue* self);
  bool (*is_boolean)(const JsonValue* self);
  bool (*is_true)(const JsonValue* self);
  bool (*is_false)(const JsonValue* self);
  bool (*is_null)(const JsonValue* self);
  const JsonObject* (*as_object)(const JsonValue* self);
  const JsonArray* (*as_array)(const JsonValue* self);
  const char* (*to_string)(const JsonValue* self);
} JsonValueVtbl;

struct JsonValue {
  const JsonValueVtbl* vt;
};

static bool JsonValue_no(const JsonValue* self) {
  (void)self;
  return false;
}

static bool JsonValue_yes(const JsonValue* self) {
  (void)self;
  return true;
}

static const char* JsonValue_to_string(const JsonValue* self) {
  (void)self;
  return "";
}

static _Noreturn void JsonValue_not_a(const char* what, const JsonValue* self) {
  char message[256];
  snprintf(message, sizeof(message), "%s%s", what, self->vt->to_string(self));
  error(message);
}

static const JsonObject* JsonValue_as_object(const JsonValue* self) {
  JsonValue_not_a("Not an object: ", self);
}

static const JsonArray* JsonValue_as_array(const JsonValue* self) {
  JsonValue_not_a("Not an array: ", self);
}

static void JsonValue_destroy(JsonValue* self) {
  self->vt->destroy(self);
}

DEFINE_VECTOR_OF_POINTERS(JsonValueVector, JsonValue*)

// ---- JsonArray

struct JsonArray {
  JsonValue base;
  JsonValueVector values;
};

static void JsonArray_destroy(JsonValue* self) {
  JsonArray* a = (JsonArray*)self;
  JsonValueVector_destroy_values(&a->values, JsonValue_destroy);
  JsonValueVector_deinit(&a->values);
  free(a);
}

static const JsonArray* JsonArray_as_array(const JsonValue* self) {
  return (const JsonArray*)self;
}

static const JsonValueVtbl JsonArray_vtbl = {
    JsonArray_destroy, JsonValue_no,        JsonValue_yes,
    JsonValue_no,      JsonValue_no,        JsonValue_no,
    JsonValue_no,      JsonValue_no,        JsonValue_no,
    JsonValue_as_object, JsonArray_as_array, JsonValue_to_string};

static JsonArray* JsonArray_new(void) {
  JsonArray* a = (JsonArray*)malloc(sizeof(JsonArray));
  a->base.vt = &JsonArray_vtbl;
  JsonValueVector_init(&a->values, 0);
  return a;
}

static void JsonArray_add(JsonArray* self, JsonValue* value) {
  if (value == NULL) {
    error("value is null");
  }
  JsonValueVector_append(&self->values, value);
}

static size_t JsonArray_size(const JsonArray* self) {
  return JsonValueVector_size(&self->values);
}

SOM_INLINE const JsonValue* JsonArray_get(const JsonArray* self, int32_t index) {
  return *JsonValueVector_at(&self->values, (size_t)index);
}

// ---- JsonLiteral

typedef struct JsonLiteral {
  JsonValue base;
  const char* value;
  bool is_null;
  bool is_true;
  bool is_false;
} JsonLiteral;

static void JsonLiteral_destroy(JsonValue* self) {
  free(self);
}

static bool JsonLiteral_is_null(const JsonValue* self) {
  return ((const JsonLiteral*)self)->is_null;
}

static bool JsonLiteral_is_true(const JsonValue* self) {
  return ((const JsonLiteral*)self)->is_true;
}

static bool JsonLiteral_is_false(const JsonValue* self) {
  return ((const JsonLiteral*)self)->is_false;
}

static bool JsonLiteral_is_boolean(const JsonValue* self) {
  const JsonLiteral* l = (const JsonLiteral*)self;
  return l->is_true || l->is_false;
}

static const char* JsonLiteral_to_string(const JsonValue* self) {
  return ((const JsonLiteral*)self)->value;
}

static const JsonValueVtbl JsonLiteral_vtbl = {
    JsonLiteral_destroy,    JsonValue_no,         JsonValue_no,
    JsonValue_no,           JsonValue_no,         JsonLiteral_is_boolean,
    JsonLiteral_is_true,    JsonLiteral_is_false, JsonLiteral_is_null,
    JsonValue_as_object,    JsonValue_as_array,   JsonLiteral_to_string};

static JsonLiteral* JsonLiteral_new(const char* value, bool is_null,
                                    bool is_true, bool is_false) {
  JsonLiteral* l = (JsonLiteral*)malloc(sizeof(JsonLiteral));
  l->base.vt = &JsonLiteral_vtbl;
  l->value = value;
  l->is_null = is_null;
  l->is_true = is_true;
  l->is_false = is_false;
  return l;
}

static JsonLiteral* JsonLiteral_create_null(void) {
  return JsonLiteral_new("null", true, false, false);
}

static JsonLiteral* JsonLiteral_create_true(void) {
  return JsonLiteral_new("true", false, true, false);
}

static JsonLiteral* JsonLiteral_create_false(void) {
  return JsonLiteral_new("false", false, false, true);
}

// ---- JsonNumber

typedef struct JsonNumber {
  JsonValue base;
  String string;
} JsonNumber;

static void JsonNumber_destroy(JsonValue* self) {
  free(((JsonNumber*)self)->string.data);
  free(self);
}

static const char* JsonNumber_to_string(const JsonValue* self) {
  return ((const JsonNumber*)self)->string.data;
}

static const JsonValueVtbl JsonNumber_vtbl = {
    JsonNumber_destroy,  JsonValue_no,       JsonValue_no,
    JsonValue_yes,       JsonValue_no,       JsonValue_no,
    JsonValue_no,        JsonValue_no,       JsonValue_no,
    JsonValue_as_object, JsonValue_as_array, JsonNumber_to_string};

static JsonNumber* JsonNumber_new(String string) {
  if (string.len == 0) {
    error("value is null");
  }
  JsonNumber* n = (JsonNumber*)malloc(sizeof(JsonNumber));
  n->base.vt = &JsonNumber_vtbl;
  n->string = string;
  return n;
}

// ---- JsonObject

struct JsonObject {
  JsonValue base;
  StringVector names;
  JsonValueVector values;
  HashIndexTable table;
};

static int32_t JsonObject_index_of(const JsonObject* self, const char* name,
                                   size_t name_len) {
  const int32_t index = HashIndexTable_get(&self->table, name_len);
  if (index != -1 &&
      String_equals(*StringVector_at(&self->names, (size_t)index), name,
                    name_len)) {
    return index;
  }
  error("not yet implemented, not relevant for the benchmark");
}

static void JsonObject_destroy(JsonValue* self) {
  JsonObject* o = (JsonObject*)self;
  for (size_t i = o->names.first_idx; i < o->names.last_idx; i += 1) {
    free(o->names.storage[i].data);
  }
  StringVector_deinit(&o->names);
  JsonValueVector_destroy_values(&o->values, JsonValue_destroy);
  JsonValueVector_deinit(&o->values);
  free(o);
}

static const JsonObject* JsonObject_as_object(const JsonValue* self) {
  return (const JsonObject*)self;
}

static const JsonValueVtbl JsonObject_vtbl = {
    JsonObject_destroy,   JsonValue_yes,      JsonValue_no,
    JsonValue_no,         JsonValue_no,       JsonValue_no,
    JsonValue_no,         JsonValue_no,       JsonValue_no,
    JsonObject_as_object, JsonValue_as_array, JsonValue_to_string};

static JsonObject* JsonObject_new(void) {
  JsonObject* o = (JsonObject*)malloc(sizeof(JsonObject));
  o->base.vt = &JsonObject_vtbl;
  StringVector_init(&o->names, 0);
  JsonValueVector_init(&o->values, 0);
  memset(o->table.hash_table, 0, sizeof(o->table.hash_table));
  return o;
}

// Takes ownership of name (C++ copies it in and the caller destroys its own).
static void JsonObject_add(JsonObject* self, String name, JsonValue* value) {
  if (name.len == 0) {
    error("name is null");
  }
  if (value == NULL) {
    error("value is null");
  }
  HashIndexTable_add(&self->table, name,
                     (int32_t)StringVector_size(&self->names));
  StringVector_append(&self->names, name);
  JsonValueVector_append(&self->values, value);
}

static const JsonValue* JsonObject_get(const JsonObject* self,
                                       const char* name) {
  const size_t name_len = strlen(name);
  if (name_len == 0) {
    error("name is null");
  }
  const int32_t index = JsonObject_index_of(self, name, name_len);
  return index == -1 ? NULL : *JsonValueVector_at(&self->values, (size_t)index);
}

// ---- JsonString

typedef struct JsonString {
  JsonValue base;
  String string;
} JsonString;

static void JsonString_destroy(JsonValue* self) {
  free(((JsonString*)self)->string.data);
  free(self);
}

static const JsonValueVtbl JsonString_vtbl = {
    JsonString_destroy,  JsonValue_no,       JsonValue_no,
    JsonValue_no,        JsonValue_yes,      JsonValue_no,
    JsonValue_no,        JsonValue_no,       JsonValue_no,
    JsonValue_as_object, JsonValue_as_array, JsonValue_to_string};

static JsonString* JsonString_new(String string) {
  JsonString* s = (JsonString*)malloc(sizeof(JsonString));
  s->base.vt = &JsonString_vtbl;
  s->string = string;
  return s;
}

// ---- JsonPureStringParser

// No end of input: C++'s empty `_current`.
#define END_OF_TEXT (-1)

typedef struct JsonPureStringParser {
  char* input;
  size_t input_len;
  size_t index;
  int32_t line;
  int32_t column;
  int current;
  StringBuffer capture_buffer;
  size_t capture_start;
} JsonPureStringParser;

static JsonValue* JsonPureStringParser_read_value(JsonPureStringParser* self);

// The ParseException C++ throws and nothing catches: report and exit.
static _Noreturn void JsonPureStringParser_error(
    const JsonPureStringParser* self, const char* message) {
  char what[256];
  snprintf(what, sizeof(what), "%s at %d:%d", message, self->line,
           self->column - 1);
  error(what);
}

static bool JsonPureStringParser_is_end_of_text(
    const JsonPureStringParser* self) {
  return self->current == END_OF_TEXT;
}

static _Noreturn void JsonPureStringParser_expected(
    const JsonPureStringParser* self, const char* expected) {
  if (JsonPureStringParser_is_end_of_text(self)) {
    JsonPureStringParser_error(self, "Unexpected end of input");
  }
  char message[128];
  snprintf(message, sizeof(message), "Expected %s", expected);
  JsonPureStringParser_error(self, message);
}

static void JsonPureStringParser_read(JsonPureStringParser* self) {
  if ('\n' == self->current) {
    self->line += 1;
    self->column = 0;
  }
  self->index += 1;
  if (self->index < self->input_len) {
    self->current = (unsigned char)self->input[self->index];
  } else {
    self->current = END_OF_TEXT;
  }
}

static bool JsonPureStringParser_is_white_space(
    const JsonPureStringParser* self) {
  return ' ' == self->current || '\t' == self->current ||
         '\n' == self->current || '\r' == self->current;
}

static bool JsonPureStringParser_is_digit(const JsonPureStringParser* self) {
  return '0' == self->current || '1' == self->current ||
         '2' == self->current || '3' == self->current ||
         '4' == self->current || '5' == self->current ||
         '6' == self->current || '7' == self->current ||
         '8' == self->current || '9' == self->current;
}

static bool JsonPureStringParser_read_char(JsonPureStringParser* self,
                                           int ch) {
  if (self->current != ch) {
    return false;
  }
  JsonPureStringParser_read(self);
  return true;
}

static bool JsonPureStringParser_read_digit(JsonPureStringParser* self) {
  if (!JsonPureStringParser_is_digit(self)) {
    return false;
  }
  JsonPureStringParser_read(self);
  return true;
}

static void JsonPureStringParser_skip_white_space(JsonPureStringParser* self) {
  while (JsonPureStringParser_is_white_space(self)) {
    JsonPureStringParser_read(self);
  }
}

static void JsonPureStringParser_start_capture(JsonPureStringParser* self) {
  self->capture_start = self->index;
}

static void JsonPureStringParser_pause_capture(JsonPureStringParser* self) {
  const size_t end = self->current == END_OF_TEXT ? self->index : self->index - 1;
  StringBuffer_append(&self->capture_buffer, self->input + self->capture_start,
                      end - self->capture_start + 1);
  self->capture_start = SIZE_MAX;
}

static String JsonPureStringParser_end_capture(JsonPureStringParser* self) {
  const size_t end = self->current == END_OF_TEXT ? self->index : self->index - 1;
  String captured;
  if (self->capture_buffer.len == 0) {
    captured = String_copy(self->input + self->capture_start,
                           end - self->capture_start + 1);
  } else {
    StringBuffer_append(&self->capture_buffer,
                        self->input + self->capture_start,
                        end - self->capture_start + 1);
    captured = String_copy(self->capture_buffer.data, self->capture_buffer.len);
    self->capture_buffer.len = 0;
  }
  self->capture_start = SIZE_MAX;
  return captured;
}

static void JsonPureStringParser_read_required_char(JsonPureStringParser* self,
                                                    int ch) {
  if (!JsonPureStringParser_read_char(self, ch)) {
    char expected[4] = {'\'', (char)ch, '\'', '\0'};
    JsonPureStringParser_expected(self, expected);
  }
}

static void JsonPureStringParser_read_escape(JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  char escaped;
  if (self->current == '"' || self->current == '/' || self->current == '\\') {
    escaped = (char)self->current;
  } else if (self->current == 'b') {
    escaped = '\b';
  } else if (self->current == 'f') {
    escaped = '\f';
  } else if (self->current == 'n') {
    escaped = '\n';
  } else if (self->current == 'r') {
    escaped = '\r';
  } else if (self->current == 't') {
    escaped = '\t';
  } else {
    JsonPureStringParser_expected(self, "valid escape sequence");
  }
  StringBuffer_append(&self->capture_buffer, &escaped, 1);
  JsonPureStringParser_read(self);
}

static String JsonPureStringParser_read_string_internal(
    JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  JsonPureStringParser_start_capture(self);
  while (self->current != '"') {
    if (self->current == '\\') {
      JsonPureStringParser_pause_capture(self);
      JsonPureStringParser_read_escape(self);
      JsonPureStringParser_start_capture(self);
    } else {
      JsonPureStringParser_read(self);
    }
  }
  String string = JsonPureStringParser_end_capture(self);
  JsonPureStringParser_read(self);
  return string;
}

static String JsonPureStringParser_read_name(JsonPureStringParser* self) {
  if (self->current != '"') {
    JsonPureStringParser_expected(self, "name");
  }
  return JsonPureStringParser_read_string_internal(self);
}

static JsonObject* JsonPureStringParser_read_object(
    JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  JsonObject* object = JsonObject_new();
  JsonPureStringParser_skip_white_space(self);
  if (JsonPureStringParser_read_char(self, '}')) {
    return object;
  }
  do {
    JsonPureStringParser_skip_white_space(self);
    const String name = JsonPureStringParser_read_name(self);
    JsonPureStringParser_skip_white_space(self);
    if (!JsonPureStringParser_read_char(self, ':')) {
      JsonPureStringParser_expected(self, "':'");
    }
    JsonPureStringParser_skip_white_space(self);

    JsonObject_add(object, name, JsonPureStringParser_read_value(self));
    JsonPureStringParser_skip_white_space(self);
  } while (JsonPureStringParser_read_char(self, ','));
  if (!JsonPureStringParser_read_char(self, '}')) {
    JsonPureStringParser_expected(self, "',' or '}'");
  }
  return object;
}

static JsonArray* JsonPureStringParser_read_array(JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  JsonArray* array = JsonArray_new();
  JsonPureStringParser_skip_white_space(self);
  if (JsonPureStringParser_read_char(self, ']')) {
    return array;
  }
  do {
    JsonPureStringParser_skip_white_space(self);
    JsonArray_add(array, JsonPureStringParser_read_value(self));
    JsonPureStringParser_skip_white_space(self);
  } while (JsonPureStringParser_read_char(self, ','));

  if (!JsonPureStringParser_read_char(self, ']')) {
    JsonPureStringParser_expected(self, "',' or ']'");
  }
  return array;
}

static JsonValue* JsonPureStringParser_read_null(JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  JsonPureStringParser_read_required_char(self, 'u');
  JsonPureStringParser_read_required_char(self, 'l');
  JsonPureStringParser_read_required_char(self, 'l');
  return &JsonLiteral_create_null()->base;
}

static JsonValue* JsonPureStringParser_read_true(JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  JsonPureStringParser_read_required_char(self, 'r');
  JsonPureStringParser_read_required_char(self, 'u');
  JsonPureStringParser_read_required_char(self, 'e');
  return &JsonLiteral_create_true()->base;
}

static JsonValue* JsonPureStringParser_read_false(JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  JsonPureStringParser_read_required_char(self, 'a');
  JsonPureStringParser_read_required_char(self, 'l');
  JsonPureStringParser_read_required_char(self, 's');
  JsonPureStringParser_read_required_char(self, 'e');
  return &JsonLiteral_create_false()->base;
}

static JsonValue* JsonPureStringParser_read_string(JsonPureStringParser* self) {
  return &JsonString_new(JsonPureStringParser_read_string_internal(self))->base;
}

static bool JsonPureStringParser_read_fraction(JsonPureStringParser* self) {
  if (!JsonPureStringParser_read_char(self, '.')) {
    return false;
  }
  if (!JsonPureStringParser_read_digit(self)) {
    JsonPureStringParser_expected(self, "digit");
  }
  while (JsonPureStringParser_read_digit(self)) {
  }

  return true;
}

static bool JsonPureStringParser_read_exponent(JsonPureStringParser* self) {
  if (!JsonPureStringParser_read_char(self, 'e') &&
      !JsonPureStringParser_read_char(self, 'E')) {
    return false;
  }
  if (!JsonPureStringParser_read_char(self, '+')) {
    JsonPureStringParser_read_char(self, '-');
  }
  if (!JsonPureStringParser_read_digit(self)) {
    JsonPureStringParser_expected(self, "digit");
  }

  while (JsonPureStringParser_read_digit(self)) {
  }
  return true;
}

static JsonValue* JsonPureStringParser_read_number(JsonPureStringParser* self) {
  JsonPureStringParser_start_capture(self);
  JsonPureStringParser_read_char(self, '-');
  const int first_digit = self->current;
  if (!JsonPureStringParser_read_digit(self)) {
    JsonPureStringParser_expected(self, "digit");
  }
  if (first_digit != '0') {
    while (JsonPureStringParser_read_digit(self)) {
    }
  }
  JsonPureStringParser_read_fraction(self);
  JsonPureStringParser_read_exponent(self);
  return &JsonNumber_new(JsonPureStringParser_end_capture(self))->base;
}

static JsonValue* JsonPureStringParser_read_value(JsonPureStringParser* self) {
  if (self->current == 'n') {
    return JsonPureStringParser_read_null(self);
  }
  if (self->current == 't') {
    return JsonPureStringParser_read_true(self);
  }
  if (self->current == 'f') {
    return JsonPureStringParser_read_false(self);
  }
  if (self->current == '"') {
    return JsonPureStringParser_read_string(self);
  }
  if (self->current == '[') {
    return &JsonPureStringParser_read_array(self)->base;
  }
  if (self->current == '{') {
    return &JsonPureStringParser_read_object(self)->base;
  }
  if (self->current == '-' || self->current == '0' || self->current == '1' ||
      self->current == '2' || self->current == '3' || self->current == '4' ||
      self->current == '5' || self->current == '6' || self->current == '7' ||
      self->current == '8' || self->current == '9') {
    return JsonPureStringParser_read_number(self);
  }

  JsonPureStringParser_expected(self, "value");
}

// The constructor takes its string by value: the parser owns a copy.
static void JsonPureStringParser_init(JsonPureStringParser* self,
                                      const char* string, size_t len) {
  self->input = (char*)malloc(len);
  memcpy(self->input, string, len);
  self->input_len = len;
  self->index = SIZE_MAX;
  self->line = 1;
  self->column = 0;
  self->current = END_OF_TEXT;
  self->capture_buffer = (StringBuffer){NULL, 0, 0};
  self->capture_start = SIZE_MAX;
}

static void JsonPureStringParser_deinit(JsonPureStringParser* self) {
  free(self->input);
  free(self->capture_buffer.data);
}

static JsonValue* JsonPureStringParser_parse(JsonPureStringParser* self) {
  JsonPureStringParser_read(self);
  JsonPureStringParser_skip_white_space(self);
  JsonValue* result = JsonPureStringParser_read_value(self);
  JsonPureStringParser_skip_white_space(self);
  if (!JsonPureStringParser_is_end_of_text(self)) {
    error("Unexpected character");
  }
  return result;
}

// ---- Json

static Result Json_benchmark(Benchmark* self) {
  (void)self;
  JsonPureStringParser parser;
  JsonPureStringParser_init(&parser, rap_benchmark_minified,
                            sizeof(rap_benchmark_minified) - 1);
  const JsonValue* const result = JsonPureStringParser_parse(&parser);
  JsonPureStringParser_deinit(&parser);
  return (Result){.p = result};
}

static bool Json_has_expected_content(Benchmark* self, const JsonValue* result) {
  (void)self;
  if (!result->vt->is_object(result)) {
    return false;
  }
  const JsonObject* result_object = result->vt->as_object(result);
  const JsonValue* head = JsonObject_get(result_object, "head");
  if (!head->vt->is_object(head)) {
    return false;
  }
  const JsonValue* operations = JsonObject_get(result_object, "operations");
  if (!operations->vt->is_array(operations)) {
    return false;
  }
  operations = JsonObject_get(result_object, "operations");
  const JsonArray* result_array = operations->vt->as_array(operations);
  return JsonArray_size(result_array) == 156;
}

static bool Json_verify_result(Benchmark* self, Result r) {
  JsonValue* const result = (JsonValue*)r.p;
  const bool does_verify = Json_has_expected_content(self, result);
  result->vt->destroy(result);
  return does_verify;
}

static const BenchmarkVtbl Json_vtbl = {Benchmark_destroy, Json_benchmark,
                                        Json_verify_result,
                                        Benchmark_inner_benchmark_loop};

Benchmark* Json_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &Json_vtbl);
}
