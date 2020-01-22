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
		value := kv[1].trim_space()

		if value.starts_with("{") || value.starts_with("[") {
			return error("nested json not implemented")
		}

		key = key.replace('"', "")

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

	mut found_field_value := json_object.content[field]

	mut quoted := false
	if found_field_value[0] == `"` {
		quoted = true
	}

	found_field_value = found_field_value.replace('"', "")

	return JsonField{key: field, value: found_field_value, quoted: quoted}
}

fn (json_object JsonObject) to_json() string {
	mut fields := []string

	for k, _ in json_object.content {
		field := json_object.get(k) or {
			// TODO: How to handle this?
			continue
		}
		mut parsed_value := field.value

		guessed_type := field.guess_type()
		if guessed_type == "string" {
			parsed_value = '"$field.value"'
		} else if guessed_type == "object" {
			parsed_value = field.as_json_object().to_json()
		} else if guessed_type == "array" {
			panic("json array not supported yet")
		}

		fields << '"$k":$parsed_value'
	}

	return "{" + fields.join(",") + "}"
}

struct JsonField {
pub:
	key string
	value string
	quoted bool
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

fn (json_field JsonField) as_json_object() JsonObject {
	json_object := parse_json_object(json_field.value) or {
		// TODO: Proper handling
		panic("well...")
	} 

	return json_object
}

fn (json_field JsonField) is_null() bool {
	return json_field.value == "null"
}

fn (json_field JsonField) guess_type() string {
	value := json_field.value

	if json_field.quoted {
		return "string"
	}

	mut re_numeric, _, _ := regex.regex(r"^-?\d*\.?\d*$")
	mut re_object, _, _ := regex.regex(r"^\{.*\}$")
	mut re_array, _, _ := regex.regex(r"^\[.*\]$")
	mut re_boolean, _, _ := regex.regex(r"^(true)|(false)$")
	mut re_null, _, _ := regex.regex(r"^null$")

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