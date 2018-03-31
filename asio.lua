
local co_create = coroutine.create
local co_status = coroutine.status 
local yield = coroutine.yield
local resume = coroutine.resume
local running = coroutine.running

local ok, new_table = pcall(require, "table.new")
if not ok then new_table = function() return {} end end

------------------ffi------------------------

local ok, ffi = pcall(require, "ffi")
assert(ok, 'need use luajit yet')

ok, asio_c = pcall(ffi.load, 'asio.so')
if not ok then asio_c = pcall(ffi.load, 'asio.dll') end
assert(asio_c, 'load c lib failed.')

local C = ffi.C

ffi.cdef[[
    struct event_message_for_ffi {
        char type;
        int dest_id;
        void* source;
        const char* data;
        size_t data_len;
    };
    event_message_for_ffi asio_get(void);

    void* asio_new_connect(const char* host, const char* port, int dest_id);
    void asio_delete_connection(void* p);
    void asio_conn_read(void* p, size_t size, int dest_id);
    void asio_conn_write(void* p, const char* data, size_t size, int dest_id);

    void* asio_new_server(const char* ip, int port);
    void asio_delete_server(void* p)
]]

----------------------------------------------------

local th_tbl = new_table(100, 0)
local th_free_id = new_table(100, 0)
local th_to_id = new_table(0, 100)

------------------connection------------------------

local connection_M = {}

function _M:get_original_dst(data)
    return asio_c.get_original_dst(self.cpoint)
end

function _M:read(n)
    local th = running()
    assert(th)
    asio_c.asio_conn_read(self.cpointid, n, th_to_id[th])
    local ok, data = yield()
    if ok then
        return data
    else
        return nil, data
    end
end

function _M:write(data)
    local th = running()
    assert(th)
    asio_c.asio_conn_write(self.cpoint, data, th_to_id[th])
    local ok, err_msg = yield()
    if ok then
        return true
    else
        return nil, err_msg
    end
end

------------------thread------------------------

local _M = {}
_M.__index = _M

local function _remove_th(tid)
    if not th_tbl[tid] then return end

    local th = th_tbl[tid]
    th_to_id[th] = nil    
    th_tbl[tid] = nil
    th_free_id[#th_free_id + 1] = tid
end

local function _light_thread(tid, func, ...)
    func(...)
    _remove_th(tid)
end

local function _create_th()
    local last_free = #th_free_id
    local tid
    if last_free == 0 then
        tid = #th_tbl + 1
    else
        tid = th_free_id[last_free]
        th_free_id[last_free] = nil
    end

    local th = co_create(_light_thread)
    th_tbl[tid] = th
    th_to_id[th] = tid

    return tid, th
end

function _M.spawn_light_thread(func, ...) 
    local tid, th = _create_th()
    resume(th, tid, func, ...)
    return th
end

------------------asio------------------------

local EVT_ACCEPT = 1
local EVT_CONTINUE = 2

local handler_tbl = {}

local function _make_connection(cpoint)
    local con = {
        __index = connection_M,
        cpoint = ffi.gc(cpoint, asio_c.asio_delete_connection),
    }
    return con
end

local function _evt_disp(evt) 
    if evt.type == EVT_ACCEPT then

        local handler = handler_tbl[evt.dest_id]
        local con = _make_connection(evt.source)
        handler(con)

    elseif evt.type == EVT_CONTINUE then

        local th = th_tbl[evt.dest_id]
        resume(th, evt.source, ffi.string(evt.data, evt.data_len))

    end
end

function _M.connect(host, port)
    local th = running()
    assert(th)
    asio_c.asio_new_connect(host, port, th_to_id[th])
    local cpoint, msg = yield()
    if not cpoint then return nil, msg end

    local con = _make_connection(cpoint)
    return con
end

function _M.server(ip, port, accept_handler)
    handler_tbl[port] = accept_handler
    return ffi.gc(asio_c.asio_new_server(ip, port), asio_c.asio_delete_server)
end

function _M.run()

    while true do
        local evt = asio_c.asio_get()
        _evt_disp(evt)
    end
end

return _M
