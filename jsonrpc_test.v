module jsonrpc

fn test_get_text_between() {
	test_cases := [
		[
			'{"key1": "val1", "key2": "val2"}',
			'{',
			'}',
			'"key1": "val1", "key2": "val2"'
		],
		[
			'{}',
			'{',
			'}',
			''
		],
		[
			'',
			'{',
			'}',
			''
		],
	]

	for test_case in test_cases {
		assert get_text_between(test_case[0], test_case[1], test_case[2]) == test_case[3]
	}
}

fn test_register_procedure() {
	mut server := new()

	server.register_procedure("sample", sample_procedure)

	assert server.procs.len == 1
}

fn test_process_raw_request() {
	// For now it only supports string args
	json_str := '{"jsonrpc": "2.0", "method": "subtract", "params": {"left": "40", "right": "20"}, "id": 1}'

	// TODO: Make the second parameter reflect reality and test if accordling
	raw_request := process_raw_request(json_str, "")

	assert raw_request.jsonrpc == "2.0"
	assert raw_request.id == 1
	assert raw_request.method == "subtract"
	// assert raw_request.headers == {}
	assert raw_request.params == '{"left":"40","right":"20"}'
}

fn test_process_request() {
	raw_request := RawRequest{
		jsonrpc: "2.0"
		id: 1
		method: "subtract"
		// headers: {}
		params: '{"left":"40","right":"20"}'
	}

	request := process_request(raw_request)

	assert request.jsonrpc == "2.0"
	assert request.id == 1
	assert request.method == "subtract"
	assert request.params["left"] == "40"
	assert request.params["right"] == "20"
}

// helpers

fn sample_procedure(ctx Context) string {
	return 'ok'
}

fn sample_subtract_procedure(ctx Context) int {
	left := ctx.req.params["left"].int()
	right := ctx.req.params["right"].int()

	return left - right
}