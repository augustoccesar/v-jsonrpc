module jsonrpc

import regex

fn parse_json_object(s string) ?JsonObject {
	if !validate(s) {
		return error("invalid JSON format")
	}

	mut json_object := JsonObject{content: map[string]string}

	mut content := s.right(1)
	end_pos := content.last_index("}") or {
		// TODO: Shouldn't happen if correct validated
		return error("invalid JSON format")
	}

	content = content.left(end_pos)

	key_val_strings := content.split(",")
	for kv_string in key_val_strings {
		kv := kv_string.split(":")

		mut key := kv[0].trim_space()
		mut value := kv[1].trim_space()

		if value.starts_with("{") || value.starts_with("[") {
			return error("nested json not implemented")
		}

		key = key.replace('"', "")
		value = value.replace('"', "")

		json_object.content[key] = value
	}

	return json_object
}

fn parse_json_array(json string) ?JsonArray {
	panic("not implemented. Waiting response on #3525 on vlang repo")
}

fn validate(json string) bool {
	// TODO: Implement validation
	return true
}

struct JsonArray {
	content []map[string]string
}

fn (json_array JsonArray) get(index int) ?JsonObject {
	// if json_array.content.len > index + 1 {
	// 	value := json_array.content[index]
	// 	return JsonObject{content: value}
	// }
	// TODO: Implement
	panic("not implemented. Waiting response on #3525 on vlang repo")
}

struct JsonObject {
mut:
	content map[string]string
}

fn (json_object JsonObject) get(field string) ?JsonField {
	if !(field in json_object.content) {
		return error("field not found")
	}

	found_field_value := json_object.content[field]

	return JsonField{key: field, value: found_field_value}
}

fn (json_object JsonObject) to_json() string {
	panic("not implemented yet")
}

struct JsonField {
pub:
	key string
	value string
}

fn (json_field JsonField) as_str() string {
	return json_field.value
}

fn (json_field JsonField) as_int() int {
	return json_field.value.int()
}

fn (json_field JsonField) as_bool() bool {
	return json_field.value.bool()
}

fn (json_field JsonField) is_null() bool {
	return json_field.value == "null"
}

fn (json_field JsonField) guess_type() string {
	// numeric_regex := "^-?\d*\.?\d*$"
	// object_regex := "^{.*}$"
	// array_regex := "^[.*]$"
	// boolean_regex := "^true|false$"
	// null_regex := "^null$"

	value := json_field.value

	mut re_numeric, _, _ := regex.regex("^-?\d*\.?\d*$")
	mut re_object, _, _ := regex.regex("^\{.*\}$")
	mut re_array, _, _ := regex.regex("^[.*]$")
	mut re_boolean, _, _ := regex.regex("^(true)|(false)$")
	mut re_null, _, _ := regex.regex("^null$")

	mut start, _ := re_numeric.match_string(value)
	if start > -1 {
		return "numeric"
	}

	start, _ = re_object.match_string(value)
	if start > -1 {
		return "object"
	}

	start, _ = re_array.match_string(value)
	if start > -1 {
		return "array"
	}

	start, _ = re_boolean.match_string(value)
	if start > -1 {
		return "boolean"
	}

	start, _ = re_null.match_string(value)
	if start > -1 {
		return "null"
	}

	// Default
	return "string"
}