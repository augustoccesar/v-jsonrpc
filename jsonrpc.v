module jsonrpc

import (
	net
	json
	log
	net.http
)

pub const (
    PARSE_ERROR = -32700
    INVALID_REQUEST = -32600
    METHOD_NOT_FOUND = -32601
    INVALID_PARAMS = -32602
    INTERNAL_ERROR = -32693    
    SERVER_ERROR_START = -32099
    SERVER_ERROR_END = -32600
    SERVER_NOT_INITIALIZED = -32002
    UNKNOWN_ERROR = -32001
)

const (
    JRPC_VERSION = '2.0'
)

pub struct Context {
pub mut:
	res Response
	req Request
	raw RawRequest
}

struct Procedure {
	name string
	func fn (Context) string
}

struct RawRequest {
mut:
    jsonrpc string
    id int
    method string
	headers map[string]string [skip]
    params string [raw]
}

pub struct Request {
pub:
    jsonrpc string
    id int
    method string
mut:
	// TODO: Support array params
    params JsonObject
}

pub struct Response {
    jsonrpc string
mut:
    id int
    error ResponseError [json:error]
    result string
}

struct ResponseError {
mut:
    code int
    message string
    // TODO: Support JsonObject&JsonArray on data
    data string
}

fn (error ResponseError) json() string {
	mut jo := JsonObject{content: map[string]string}

	// TODO: Figure out why is this breaking
	// jo.content["code"] = error.code.str()
	// jo.content["message"] = error.message
	// jo.content["data"] = error.data

	jo.content["code"] = "code"
	jo.content["message"] = "message"
	jo.content["data"] = "data"

	return jo.to_json()
}

pub fn (res mut Response) send_error(err_code int) {
	mut error := ResponseError{ code: err_code, data: '' }
	error.message = err_message(err_code)
	res.error = error
}

fn err_message(err_code int) string {
	msg := match err_code {
		PARSE_ERROR { 'Invalid JSON' }
		INVALID_PARAMS { 'Invalid params.' }
		INVALID_REQUEST { 'Invalid request.' }
		METHOD_NOT_FOUND { 'Method not found.' }
		SERVER_ERROR_END { 'Error while stopping the server.' }
		SERVER_NOT_INITIALIZED { 'Server not yet initialized.' }
		SERVER_ERROR_START { 'Error while starting the server.' }
		else { 'Unknown error.' }
	}

	return msg
}

fn (res Response) json() string {
	mut jo := JsonObject{content: map[string]string}

	// TODO: Figure a way to not have to wrap this in quotes
	jo.content["jsonrpc"] = '"$res.jsonrpc"'
	jo.content["id"] = res.id.str()

	if res.error.message.len != 0 {
		jo.content["error"] = res.error.json()
	} else {
		jo.content["result"] = res.result
	}

	return jo.to_json()
}

pub fn (err ResponseError) str() string {
	return json.encode(err)
}

fn (res &Response) send(conn net.Socket) {
	mut logg := log.Log{ level: 4 }
	res_json := res.json()

	// TODO: is there a way to avoid this dup of `or`?
	conn.write('Content-Length: ${res_json.len}\r') or {
		logg.error("something went wrong during socket write")
	}
	conn.write('') or {
		logg.error("something went wrong during socket write")
	}
	conn.write(res_json) or {
		logg.error("something went wrong during socket write")
	}
}

fn process_request(raw_req RawRequest) Request {
	mut req := Request{JRPC_VERSION, raw_req.id, raw_req.method, JsonObject{}}

	json_object := parse_json_object(raw_req.params) or {
		//TODO: Maybe a better solution than panic?
		panic("unable to parse param json")
	}

	req.params = json_object

	return req
}

fn create_raw_request(json_str string, raw_contents string) RawRequest {
	mut raw_req := RawRequest{}
	raw_req.headers = http.parse_headers(raw_contents.split_into_lines())

	if json_str == '{}' {
		return raw_req
	} else {
		from_json := json.decode(RawRequest, json_str) or { return raw_req }

		return from_json
	}
}

pub struct Server {
mut:
	port int
	procs []Procedure
}

fn (server Server) proc_index(name string) int {
	for i, proc in server.procs {
		if proc.name == name {
			return i
		}
	}

	return -1
}

pub fn (server mut Server) start_and_listen(port_num int) {
	server.port = port_num

	listener := net.listen(server.port) or {panic('Failed to listen to port ${server.port}')}
	mut logg := log.Log{ level: 4 }

	logg.info('JSON-RPC Server has started on port ${server.port}')
	for {
		mut res := Response{ jsonrpc: JRPC_VERSION }
		conn := listener.accept() or {
			logg.set_level(1)
			logg.error(err_message(SERVER_ERROR_START))
			res.send_error(SERVER_ERROR_START)
			return
		}
		s := conn.read_line()
		vals := s.split_into_lines()
		content := vals[vals.len-1]
		raw_req := create_raw_request(content, s)
		req := process_request(raw_req) 

		if s == '' {
			logg.set_level(2)
			logg.error(err_message(INTERNAL_ERROR))
			res.send_error(INTERNAL_ERROR)
		}

		if content == '{}' || content == '' || vals.len < 2 {
			logg.set_level(2)
			logg.error(err_message(INVALID_REQUEST))
			res.send_error(INVALID_REQUEST)
		}

		res.id = req.id
		proc_idx := server.proc_index(req.method)
		ctx := Context{res: res, req: req, raw: raw_req}

		if proc_idx != -1 {
			invoke_proc := server.procs[proc_idx].func
			proc_name := server.procs[proc_idx].name
			res.result = invoke_proc(ctx)
			logg.set_level(4)
			logg.info('[ID: ${req.id}][${req.method}] ${raw_req.params}')
		}

		res.send(conn)
		conn.close() or { return }
	}
}

// pub fn (server mut Server) register_procedure<T,U>(method_name string, proc_func fn (Context) T, result_typ U)
pub fn (server mut Server) register_procedure(method_name string, proc_func fn (Context) string) {
	proc := Procedure{ name: method_name, func: proc_func }
	server.procs << proc
}

pub fn new() Server {
	return Server{ port: 8046, procs: [] }
}
