module jsonrpc

fn test_register_procedure() {
	mut server := new()

	server.register_procedure("sample", sample_procedure)

	assert server.procs.len == 1
}

fn test_create_raw_request() {
	json_str := '{"jsonrpc": "2.0", "method": "subtract", "params": {"left": 40, "right": 20}, "id": 1}'

	// TODO: Make the second parameter reflect reality and test if accordling
	raw_request := create_raw_request(json_str, "")

	assert raw_request.jsonrpc == "2.0"
	assert raw_request.id == 1
	assert raw_request.method == "subtract"
	// assert raw_request.headers == {}
	assert raw_request.params == '{"left":40,"right":20}'
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

	actual_left := request.params.get("left") or {
		panic(err)
	}
	actual_right := request.params.get("right") or {
		panic(err)
	}

	assert 40 == actual_left.as_int()
	assert 20 == actual_right.as_int()
}

fn test_response_json() {
	responses := [
		Response{
			jsonrpc: "2.0",
			id: 1,
			result: "1"
		}
		// Response{
		// 	jsonrpc: "2.0",
		// 	id: 1,
		// 	error: ResponseError {
		// 		code: 1,
		// 		message: "Sample Error",
		// 		data: "data"
		// 	}
		// }
	]

	expected_results := [
		'{"jsonrpc":"2.0","id":1,"result":1}'
		// '{"jsonrpc":"2.0","id":1,"error": {"code":1,"message":"Sample Error","data":"data"}}'
	]

	for i, response in responses {
		println(response.json())
		assert expected_results[i] == response.json()
	}
}

// helpers

fn sample_procedure(ctx Context) string {
	return 'ok'
}

fn sample_subtract_procedure(ctx Context) int {
	left := ctx.req.params.get("left") or {
		panic(err)
	}
	right := ctx.req.params.get("right") or {
		panic(err)
	}

	return left.as_int() - right.as_int()
}