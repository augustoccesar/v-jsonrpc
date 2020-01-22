module jsonrpc

fn test_parse_json_object() {
	expected := {
		"key1": "val1", 
		"key2": "val2"
	}

	result := parse_json_object('{"key1": "val1", "key2": "val2"}') or {
		panic(err)
	}

	for key, _ in expected {
		result_val := result.get(key) or {
			panic(err)
		}

		assert expected[key] == result_val.as_str()
	}
}

fn test_json_object_get() {
	content := {
		"key1": "string",
		"key2": "true",
		"key3": "1"
	}

	expected_values := [
		JsonField{key: "key1", value: "string"},
		JsonField{key: "key2", value: "true"},
		JsonField{key: "key3", value: "1"},
	]
	mut actual_values := []JsonField

	json_object := JsonObject{content: content}

	for k, v in content {
		val := json_object.get(k) or {
			panic(err)
		}
		actual_values << val
	}

	for i, expected in expected_values {
		assert expected.key == actual_values[i].key
		assert expected.value == actual_values[i].value
	}
}

fn test_json_field_conversions() {
	assert JsonField{key: "key", value: "string"}.as_str() == "string"
	assert JsonField{key: "key", value: "1"}.as_int() == 1
	assert JsonField{key: "key", value: "true"}.as_bool() == true
	assert JsonField{key: "key", value: "false"}.as_bool() == false
}

fn test_json_field_is_null() {
	assert JsonField{key: "key", value: "null"}.is_null() == true
	assert JsonField{key: "key", value: "string"}.is_null() == false
	assert JsonField{key: "key", value: "1"}.is_null() == false
	assert JsonField{key: "key", value: "0"}.is_null() == false
	assert JsonField{key: "key", value: ""}.is_null() == false
}

// TODO: Fix failling assertions
fn test_json_field_guess_type() {
	assert JsonField{key: "key", value: "null"}.guess_type() == "null"

	assert JsonField{key: "key", value: "true"}.guess_type() == "boolean"
	assert JsonField{key: "key", value: "false"}.guess_type() == "boolean"

	assert JsonField{key: "key", value: "1"}.guess_type() == "numeric"
	assert JsonField{key: "key", value: "1.0"}.guess_type() == "numeric" // Failling
	assert JsonField{key: "key", value: "1000"}.guess_type() == "numeric" // Failling
	assert JsonField{key: "key", value: "0.0000001"}.guess_type() == "numeric" // Failling
	assert JsonField{key: "key", value: "-1"}.guess_type() == "numeric"
	assert JsonField{key: "key", value: "-1.0"}.guess_type() == "numeric" // Failling
	assert JsonField{key: "key", value: "-0.00001"}.guess_type() == "numeric" // Failling

	assert JsonField{key: "key", value: '{"key", "val"}'}.guess_type() == "object"

	assert JsonField{key: "key", value: "[1, 2, 3]"}.guess_type() == "array" // Failling
}