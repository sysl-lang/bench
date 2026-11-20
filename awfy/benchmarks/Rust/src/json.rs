// Upstream C++ json.h: a recursive-descent parser over a string whose current character is itself
// a one-character string (core-language.md excludes a character type), building a tree of
// heap-allocated `JsonValue` objects, polymorphic through a trait object as C++'s are through
// virtual methods. The tree owns its children (`Box`), so freeing the root frees the document, as
// C++'s `delete result` with `destroyValues()` does.
//
// A parse error is a panic carrying C++'s `ParseException` message (C++ throws; the document is
// well formed, so neither is ever raised).

use crate::benchmark::Benchmark;
use crate::json_data::RAP_BENCHMARK_MINIFIED;
use crate::som::Vector;

struct HashIndexTable {
    hash_table: [i32; 32],
}

impl HashIndexTable {
    fn new() -> HashIndexTable {
        HashIndexTable { hash_table: [0; 32] }
    }

    fn add(&mut self, name: &str, index: i32) {
        let slot = self.hash_slot_for(name);
        if index < 0xff {
            // increment by 1, 0 stands for empty
            self.hash_table[slot] = (index + 1) & 0xff;
        } else {
            self.hash_table[slot] = 0;
        }
    }

    fn get(&self, name: &str) -> i32 {
        let slot = self.hash_slot_for(name);
        // subtract 1, 0 stands for empty
        (self.hash_table[slot] & 0xff) - 1
    }

    fn string_hash(&self, s: &str) -> i32 {
        // this is not a proper hash, but sufficient for the benchmark,
        // and very portable!
        (s.len() as i32).wrapping_mul(1402589)
    }

    fn hash_slot_for(&self, element: &str) -> usize {
        (self.string_hash(element) & (self.hash_table.len() as i32 - 1)) as usize
    }
}

trait JsonValue {
    fn is_object(&self) -> bool {
        false
    }
    fn is_array(&self) -> bool {
        false
    }
    fn is_number(&self) -> bool {
        false
    }
    fn is_string(&self) -> bool {
        false
    }
    fn is_boolean(&self) -> bool {
        false
    }
    fn is_true(&self) -> bool {
        false
    }
    fn is_false(&self) -> bool {
        false
    }
    fn is_null(&self) -> bool {
        false
    }

    fn as_object(&self) -> &JsonObject {
        panic!("Not an object: {}", self.to_string());
    }

    fn as_array(&self) -> &JsonArray {
        panic!("Not an array: {}", self.to_string());
    }

    fn to_string(&self) -> String {
        String::new()
    }
}

struct JsonArray {
    values: Vector<Box<dyn JsonValue>>,
}

impl JsonArray {
    fn new() -> JsonArray {
        JsonArray { values: Vector::new() }
    }

    fn add(&mut self, value: Box<dyn JsonValue>) {
        self.values.append(value);
    }

    fn size(&self) -> usize {
        self.values.size()
    }

    #[allow(dead_code)]
    fn get(&self, index: usize) -> &dyn JsonValue {
        self.values.at(index).unwrap().as_ref()
    }
}

impl JsonValue for JsonArray {
    fn is_array(&self) -> bool {
        true
    }
    fn as_array(&self) -> &JsonArray {
        self
    }
}

struct JsonLiteral {
    value: String,
    is_null: bool,
    is_true: bool,
    is_false: bool,
}

impl JsonLiteral {
    fn new(value: &str, is_null: bool, is_true: bool, is_false: bool) -> JsonLiteral {
        JsonLiteral { value: value.to_string(), is_null, is_true, is_false }
    }

    fn create_null() -> Box<JsonLiteral> {
        Box::new(JsonLiteral::new("null", true, false, false))
    }

    fn create_true() -> Box<JsonLiteral> {
        Box::new(JsonLiteral::new("true", false, true, false))
    }

    fn create_false() -> Box<JsonLiteral> {
        Box::new(JsonLiteral::new("false", false, false, true))
    }
}

impl JsonValue for JsonLiteral {
    fn is_null(&self) -> bool {
        self.is_null
    }
    fn is_true(&self) -> bool {
        self.is_true
    }
    fn is_false(&self) -> bool {
        self.is_false
    }
    fn is_boolean(&self) -> bool {
        self.is_true || self.is_false
    }
    fn to_string(&self) -> String {
        self.value.clone()
    }
}

struct JsonNumber {
    string: String,
}

impl JsonNumber {
    fn new(string: String) -> JsonNumber {
        if string.is_empty() {
            panic!("value is null");
        }
        JsonNumber { string }
    }
}

impl JsonValue for JsonNumber {
    fn to_string(&self) -> String {
        self.string.clone()
    }
    fn is_number(&self) -> bool {
        true
    }
}

struct JsonObject {
    names: Vector<String>,
    values: Vector<Box<dyn JsonValue>>,
    table: HashIndexTable,
}

impl JsonObject {
    fn new() -> JsonObject {
        JsonObject { names: Vector::new(), values: Vector::new(), table: HashIndexTable::new() }
    }

    fn index_of(&self, name: &str) -> i32 {
        let index = self.table.get(name);
        if index != -1 && name == self.names.at(index as usize).unwrap() {
            return index;
        }
        panic!("not yet implemented, not relevant for the benchmark");
    }

    fn add(&mut self, name: String, value: Box<dyn JsonValue>) {
        if name.is_empty() {
            panic!("name is null");
        }
        self.table.add(&name, self.names.size() as i32);
        self.names.append(name);
        self.values.append(value);
    }

    fn get(&self, name: &str) -> Option<&dyn JsonValue> {
        if name.is_empty() {
            panic!("name is null");
        }
        let index = self.index_of(name);
        if index == -1 {
            return None;
        }
        Some(self.values.at(index as usize).unwrap().as_ref())
    }

    #[allow(dead_code)]
    fn size(&self) -> usize {
        self.names.size()
    }

    #[allow(dead_code)]
    fn is_empty(&self) -> bool {
        self.names.is_empty()
    }
}

impl JsonValue for JsonObject {
    fn is_object(&self) -> bool {
        true
    }
    fn as_object(&self) -> &JsonObject {
        self
    }
}

struct JsonString {
    #[allow(dead_code)]
    string: String,
}

impl JsonString {
    fn new(string: String) -> JsonString {
        JsonString { string }
    }
}

impl JsonValue for JsonString {
    fn is_string(&self) -> bool {
        true
    }
}

struct ParseException {
    message: String,
    #[allow(dead_code)]
    offset: usize,
    line: i32,
    column: i32,
}

impl std::fmt::Display for ParseException {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} at {}:{}", self.message, self.line, self.column)
    }
}

/// C++ takes the document by value, copying it into the parser; here the caller makes that copy
/// and the parser borrows it, so `current` can be a one-character slice of it.
struct JsonPureStringParser<'s> {
    input: &'s str,
    index: usize,
    line: i32,
    column: i32,
    current: &'s str,
    capture_buffer: String,
    capture_start: usize,
}

impl<'s> JsonPureStringParser<'s> {
    fn new(string: &'s str) -> Self {
        JsonPureStringParser {
            input: string,
            index: usize::MAX,
            line: 1,
            column: 0,
            current: "",
            capture_buffer: String::new(),
            capture_start: usize::MAX,
        }
    }

    fn read_value(&mut self) -> Box<dyn JsonValue> {
        if self.current == "n" {
            return self.read_null();
        }
        if self.current == "t" {
            return self.read_true();
        }
        if self.current == "f" {
            return self.read_false();
        }
        if self.current == "\"" {
            return self.read_string();
        }
        if self.current == "[" {
            return self.read_array();
        }
        if self.current == "{" {
            return self.read_object();
        }
        if self.current == "-"
            || self.current == "0"
            || self.current == "1"
            || self.current == "2"
            || self.current == "3"
            || self.current == "4"
            || self.current == "5"
            || self.current == "6"
            || self.current == "7"
            || self.current == "8"
            || self.current == "9"
        {
            return self.read_number();
        }

        panic!("{}", self.expected("value"));
    }

    fn read_object(&mut self) -> Box<JsonObject> {
        self.read();
        let mut object = Box::new(JsonObject::new());
        self.skip_white_space();
        if self.read_char("}") {
            return object;
        }
        // C++'s do-while: Rust has none, and core-language.md excludes `break`.
        let mut more = true;
        while more {
            self.skip_white_space();
            let name = self.read_name();
            self.skip_white_space();
            if !self.read_char(":") {
                panic!("{}", self.expected("':'"));
            }
            self.skip_white_space();

            object.add(name, self.read_value());
            self.skip_white_space();
            more = self.read_char(",");
        }
        if !self.read_char("}") {
            panic!("{}", self.expected("',' or '}'"));
        }
        object
    }

    fn read_name(&mut self) -> String {
        if self.current != "\"" {
            panic!("{}", self.expected("name"));
        }
        self.read_string_internal()
    }

    fn read_array(&mut self) -> Box<JsonArray> {
        self.read();
        let mut array = Box::new(JsonArray::new());
        self.skip_white_space();
        if self.read_char("]") {
            return array;
        }
        let mut more = true;
        while more {
            self.skip_white_space();
            array.add(self.read_value());
            self.skip_white_space();
            more = self.read_char(",");
        }

        if !self.read_char("]") {
            panic!("{}", self.expected("',' or ']'"));
        }
        array
    }

    fn read_null(&mut self) -> Box<dyn JsonValue> {
        self.read();
        self.read_required_char("u");
        self.read_required_char("l");
        self.read_required_char("l");
        JsonLiteral::create_null()
    }

    fn read_true(&mut self) -> Box<dyn JsonValue> {
        self.read();
        self.read_required_char("r");
        self.read_required_char("u");
        self.read_required_char("e");
        JsonLiteral::create_true()
    }

    fn read_false(&mut self) -> Box<dyn JsonValue> {
        self.read();
        self.read_required_char("a");
        self.read_required_char("l");
        self.read_required_char("s");
        self.read_required_char("e");
        JsonLiteral::create_false()
    }

    fn read_required_char(&mut self, ch: &str) {
        if !self.read_char(ch) {
            panic!("{}", self.expected(&format!("'{ch}'")));
        }
    }

    fn read_string(&mut self) -> Box<dyn JsonValue> {
        Box::new(JsonString::new(self.read_string_internal()))
    }

    fn read_string_internal(&mut self) -> String {
        self.read();
        self.start_capture();
        while self.current != "\"" {
            if self.current == "\\" {
                self.pause_capture();
                self.read_escape();
                self.start_capture();
            } else {
                self.read();
            }
        }
        let string = self.end_capture();
        self.read();
        string
    }

    fn read_escape(&mut self) {
        self.read();
        if self.current == "\"" || self.current == "/" || self.current == "\\" {
            self.capture_buffer += self.current;
        } else if self.current == "b" {
            self.capture_buffer += "\u{8}";
        } else if self.current == "f" {
            self.capture_buffer += "\u{c}";
        } else if self.current == "n" {
            self.capture_buffer += "\n";
        } else if self.current == "r" {
            self.capture_buffer += "\r";
        } else if self.current == "t" {
            self.capture_buffer += "\t";
        } else {
            panic!("{}", self.expected("valid escape sequence"));
        }
        self.read();
    }

    fn read_number(&mut self) -> Box<dyn JsonValue> {
        self.start_capture();
        self.read_char("-");
        let first_digit = self.current;
        if !self.read_digit() {
            panic!("{}", self.expected("digit"));
        }
        if first_digit != "0" {
            while self.read_digit() {}
        }
        self.read_fraction();
        self.read_exponent();
        Box::new(JsonNumber::new(self.end_capture()))
    }

    fn read_fraction(&mut self) -> bool {
        if !self.read_char(".") {
            return false;
        }
        if !self.read_digit() {
            panic!("{}", self.expected("digit"));
        }
        while self.read_digit() {}

        true
    }

    fn read_exponent(&mut self) -> bool {
        if !self.read_char("e") && !self.read_char("E") {
            return false;
        }
        if !self.read_char("+") {
            self.read_char("-");
        }
        if !self.read_digit() {
            panic!("{}", self.expected("digit"));
        }

        while self.read_digit() {}
        true
    }

    fn read_char(&mut self, ch: &str) -> bool {
        if self.current != ch {
            return false;
        }
        self.read();
        true
    }

    fn read_digit(&mut self) -> bool {
        if !self.is_digit() {
            return false;
        }
        self.read();
        true
    }

    fn skip_white_space(&mut self) {
        while self.is_white_space() {
            self.read();
        }
    }

    fn read(&mut self) {
        if "\n" == self.current {
            self.line += 1;
            self.column = 0;
        }
        self.index = self.index.wrapping_add(1);
        if self.index < self.input.len() {
            self.current = &self.input[self.index..self.index + 1];
        } else {
            self.current = "";
        }
    }

    fn start_capture(&mut self) {
        self.capture_start = self.index;
    }

    fn pause_capture(&mut self) {
        let end = if self.current.is_empty() { self.index } else { self.index - 1 };
        self.capture_buffer += &self.input[self.capture_start..end + 1];
        self.capture_start = usize::MAX;
    }

    fn end_capture(&mut self) -> String {
        let end = if self.current.is_empty() { self.index } else { self.index - 1 };
        let captured;
        if self.capture_buffer.is_empty() {
            captured = self.input[self.capture_start..end + 1].to_string();
        } else {
            self.capture_buffer += &self.input[self.capture_start..end + 1];
            captured = std::mem::take(&mut self.capture_buffer);
        }
        self.capture_start = usize::MAX;
        captured
    }

    fn expected(&self, expected: &str) -> ParseException {
        if self.is_end_of_text() {
            return self.error("Unexpected end of input");
        }

        self.error(&format!("Expected {expected}"))
    }

    fn error(&self, message: &str) -> ParseException {
        ParseException { message: message.to_string(), offset: self.index, line: self.line, column: self.column - 1 }
    }

    fn is_white_space(&self) -> bool {
        " " == self.current || "\t" == self.current || "\n" == self.current || "\r" == self.current
    }

    fn is_digit(&self) -> bool {
        "0" == self.current
            || "1" == self.current
            || "2" == self.current
            || "3" == self.current
            || "4" == self.current
            || "5" == self.current
            || "6" == self.current
            || "7" == self.current
            || "8" == self.current
            || "9" == self.current
    }

    fn is_end_of_text(&self) -> bool {
        self.current.is_empty()
    }

    fn parse(&mut self) -> Box<dyn JsonValue> {
        self.read();
        self.skip_white_space();
        let result = self.read_value();
        self.skip_white_space();
        if !self.is_end_of_text() {
            panic!("Unexpected character");
        }
        result
    }
}

pub struct Json;

impl Json {
    fn has_expected_content(&self, result: &dyn JsonValue) -> bool {
        if !result.is_object() {
            return false;
        }
        let result_object = result.as_object();
        if !result_object.get("head").unwrap().is_object() {
            return false;
        }
        if !result_object.get("operations").unwrap().is_array() {
            return false;
        }
        let result_array = result_object.get("operations").unwrap().as_array();
        result_array.size() == 156
    }
}

impl Benchmark for Json {
    type Result = Box<dyn JsonValue>;

    fn benchmark(&mut self) -> Box<dyn JsonValue> {
        let document = String::from(RAP_BENCHMARK_MINIFIED);
        let mut parser = JsonPureStringParser::new(&document);
        parser.parse()
    }

    fn verify_result(&mut self, result: Box<dyn JsonValue>) -> bool {
        let does_verify = self.has_expected_content(result.as_ref());
        drop(result);
        does_verify
    }
}
