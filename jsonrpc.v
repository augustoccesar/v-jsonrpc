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

// struct Procedure<T> {
// 	name string
// 	func fn (Context) string
// 	result T
// }

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

// pub struct Request<T> {
// pub:
//     jsonrpc string
//     id int
//     method string
// mut:
//     params T
// }

pub struct Response {
    jsonrpc string
mut:
    id int
    error ResponseError [json:error]
    result string
}

// pub struct Response<T> {
//     jsonrpc string
// mut:
//     id int
//     error ResponseError [json:error]
//     result T
// }

struct ResponseError {
mut:
    code int
    message string
    data string
}

pub struct Server {
mut:
	port int
	procs []Procedure
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

// get_text_between gets all the text inside `s` between `start` character and `end` character
fn get_text_between(s string, start, end string) string {
	start_pos := s.index(start) or {
		return ""
	}
	
	val := s.right(start_pos + start.len)
	end_pos := val.last_index(end) or {
		return val
	}

	return val.left(end_pos)
}


fn (res Response) json() string {
	mut res_json_arr := []string

	res_json_arr << '"jsonrpc":"${res.jsonrpc}"'
	
	if res.id != 0 {
		res_json_arr << '"id":${res.id}'
	}

	if res.error.message.len != 0 {
		res_json_arr << '"error": {"code":${res.error.code},"message":"${res.error.message}","data":"${res.error.data}"}'
	} else {
		res_json_arr << '"result":"${res.result}"'
	}

	return '{' + res_json_arr.join(',') + '}'
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

fn (server Server) proc_index(name string) int {
	for i, proc in server.procs {
		if proc.name == name {
			return i
		}
	}

	return -1
}

fn process_raw_request(json_str string, raw_contents string) RawRequest {
	mut raw_req := RawRequest{}
	raw_req.headers = http.parse_headers(raw_contents.split_into_lines())

	if json_str == '{}' {
		return raw_req
	} else {
		from_json := json.decode(RawRequest, json_str) or { return raw_req }

		return from_json
	}
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
		raw_req := process_raw_request(content, s)
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
