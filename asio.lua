-- Copyright (C) by Jianhao Zhang (heeroz)

local co_create = coroutine.create
local co_status = coroutine.status
local yield = coroutine.yield
local resume = coroutine.resume
local running = coroutine.running
local setmetatable = setmetatable
local type = type
local tostring = tostring
local assert = assert

local ok, new_table = pcall(require, "table.new")
if not ok then new_table = function() return {} end end

------------------ffi------------------------

local ok, ffi = pcall(require, "ffi")
assert(ok, 'need use luajit yet')

ok, asio_c = pcall(ffi.load, 'asio.so')
if not ok then _, asio_c = pcall(ffi.load, 'asio.dll') end
assert(asio_c, 'load c lib failed.')

local C = ffi.C

ffi.cdef[[
    typedef struct event_message_for_ffi {
        char type;
        int dest_id;
        void* source;
        const char* data;
        size_t data_len;
    } event_message;
    event_message* asio_get(int wait_sec);
    bool asio_stopped();
    void asio_sleep(int dest_id, unsigned int sec);

    void* asio_new_connect(const char* host, const char* port,
        int dest_id);
    void asio_delete_connection(void* p);
    void asio_conn_read(void* p, size_t size, int dest_id);
    void asio_conn_read_some(void* p, int dest_id);
    void asio_conn_write(void* p, const char* data, size_t size,
        int dest_id);
    void asio_conn_close(void* p);
    void* asio_get_original_dst(void* p);

    void* asio_new_server(const char* ip, int port);
    void asio_delete_server(void* p);
]]

------------------thread------------------------

local _M = {}

local th_tbl = new_table(100, 0)
local th_free_id = new_table(100, 0)
local th_to_id = new_table(0, 100)

function _M._get_tid(th)
    return th_to_id[th]
end

function _M._get_free_tid()
    local last_free = #th_free_id
    local tid
    if last_free == 0 then
        tid = #th_tbl + 1
    else
        tid = th_free_id[last_free]
    end
    return tid, last_free
end

function _M._use_tid(tid, last_free, th)
    if last_free > 0 then
        th_free_id[last_free] = nil
    end
    th_tbl[tid] = th
    th_to_id[th] = tid
end

function _M._remove_th(tid)
    if not th_tbl[tid] then return end
    -- local is_thtbl_array = #th_free_id == 0
    -- local add_free = not is_thtbl_array or tid != (#th_tbl - 1)

    local th = th_tbl[tid]
    th_to_id[th] = nil
    th_tbl[tid] = nil
    --if add_free then
    th_free_id[#th_free_id + 1] = tid
    --end
end

local function _light_thread(tid, func, ...)
    func(...)
    _M._remove_th(tid)
end

local function _create_th()
    local tid, useid = _M._get_free_tid()
    -- todo: thread pool assign here
    local th = co_create(_light_thread)
    _M._use_tid(tid, useid, th)

    return tid, th
end

function _M.spawn_light_thread(func, ...)
    local tid, th = _create_th()
    local ok, err = resume(th, tid, func, ...)
    if not ok then
        print( debug.traceback( th, err ))
    end
    return th
end

------------------connection------------------------

local conn_M = {}
conn_M.__index = conn_M

local sockaddr_size = 128

function conn_M:get_original_dst(data)
    local addr = asio_c.asio_get_original_dst(self.cpoint)
    return ffi.string(addr, sockaddr_size)
end

function conn_M:read(n)
    local th = running()
    assert(th, 'need be called in light thread.')
    asio_c.asio_conn_read(self.cpoint, n, th_to_id[th])
    local ok, data = yield()
    if ok then
        return data
    else
        return nil, data
    end
end

function conn_M:read_some()
    local th = running()
    assert(th, 'need be called in light thread.')
    asio_c.asio_conn_read_some(self.cpoint, th_to_id[th])
    local ok, data = yield()
    if ok then
        return data
    else
        local ok, err = yield()
        return data, err
    end
end

function conn_M:write(data)
    local th = running()
    assert(th, 'need be called in light thread.')
    asio_c.asio_conn_write(self.cpoint, data, #data, th_to_id[th])
    local ok, err_msg = yield()
    if ok then
        return true
    else
        return nil, err_msg
    end
end

function conn_M:close()
    asio_c.asio_conn_close(self.cpoint)
    self.cpoint = nil
    setmetatable(self, nil)
end
------------------asio------------------------

local EVT_ACCEPT = 1
local EVT_CONTINUE = 2

local handler_tbl = {}

local function _make_connection(cpoint)
    local con = {
        cpoint = ffi.gc(cpoint, asio_c.asio_delete_connection),
    }
    setmetatable(con, conn_M)
    return con
end

local function _evt_disp(evt)
    if evt.type == EVT_ACCEPT then

        local handler = handler_tbl[evt.dest_id]
        local con = _make_connection(evt.source)
        handler(con)

    elseif evt.type == EVT_CONTINUE then

        local th = th_tbl[evt.dest_id]
        local source = evt.source ~= nil and evt.source or nil
        local data = ffi.string(evt.data, evt.data_len)

        local ok, err = resume(th, source, data)
        if not ok then
            print( debug.traceback( th, err ))
        end

    end
end

function _M.connect(host, port)
    if type(port) == 'number' then
        port = tostring(port)
    end
    local th = running()
    assert(th, 'need be called in light thread.')
    asio_c.asio_new_connect(host, port, th_to_id[th])
    local cpoint, msg = yield()
    if cpoint == nil then return nil, msg end

    local con = _make_connection(cpoint)
    return con
end

function _M.server(ip, port, accept_handler)
    handler_tbl[port] = accept_handler
    local sv = asio_c.asio_new_server(ip, port)
    if sv == nil then
        return nil
    else
        return ffi.gc(sv, asio_c.asio_delete_server)
    end
end

function _M.destory_server(server_holder)
    asio_c.asio_delete_server(ffi.gc(server_holder, nil))
end

function _M.sleep(sec)
    local th = running()
    assert(th, 'need be called in light thread.')
    asio_c.asio_sleep(th_to_id[th], sec)
    yield()
    return
end

function _M.run()
    while true do
        local evt = asio_c.asio_get(-1)
        if evt ~= nil then
            _evt_disp(evt)
        end
        if asio_c.asio_stopped() then break end
    end
end

function _M.run_once(wait_sec)
    local evt = asio_c.asio_get(wait_sec or -1)
    if evt ~= nil then
        _evt_disp(evt)
    end
end

return _M
