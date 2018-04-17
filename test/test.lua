
local asio = require 'asio'

-- test create and remove thread
do io.write('---- Light Thread Test ----')

    -- create 3 thread
    assert(asio._get_free_tid() == 1)
    local tid, useid = asio._get_free_tid()
    asio._use_tid(tid, useid, 't1')

    assert(asio._get_free_tid() == 2)
    local tid, useid = asio._get_free_tid()
    asio._use_tid(tid, useid, 't2')

    assert(asio._get_free_tid() == 3)
    local tid, useid = asio._get_free_tid()
    asio._use_tid(tid, useid, 't3')

    assert(asio._get_free_tid() == 4)
    assert(asio._get_tid('t2') == 2)

    --remove 1
    asio._remove_th(2)
    assert(asio._get_free_tid() == 2)

    --recreate thread
    local tid, useid = asio._get_free_tid()
    asio._use_tid(tid, useid, 'r2')

    assert(asio._get_free_tid() == 4)
    assert(asio._get_tid('t2') == nil)
    assert(asio._get_tid('r2') == 2)

    --clean
    asio._remove_th(3)
    asio._remove_th(2)
    asio._remove_th(1)
    assert(asio._get_free_tid() == 1)

    --spaw thread
    function th_test(arg1, tid)
        assert(arg1 == 'tttt')
        assert(asio._get_tid(coroutine.running()) == tid)
        coroutine.yield()
    end

    local th1 = asio.spawn_light_thread(th_test, 'tttt', 1)
    local th2 = asio.spawn_light_thread(th_test, 'tttt', 2)
    local th3 = asio.spawn_light_thread(th_test, 'tttt', 3)

    coroutine.resume(th2)
    assert(asio._get_free_tid() == 2)

    coroutine.resume(th1)
    assert(asio._get_free_tid() == 1)

    coroutine.resume(th3)
    assert(asio._get_free_tid() == 3)

end io.write(' \t[OK]\n')

--------------------------------------------------
local ffi = require("ffi")
ffi.cdef[[
void Sleep(int ms);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
]]

local sleep
if ffi.os == "Windows" then
  function sleep(s)
    ffi.C.Sleep(s*1000)
  end
else
  function sleep(s)
    ffi.C.poll(nil, 0, s*1000)
  end
end
--------------------------------------------------

--test network
--for i=1,1000
do io.write('---- C Asio Test ----')

    -- non-ip address should return nil
    assert( not asio.server('localhost', 1234) )
    -- not in light thread
    assert( pcall( asio.connect, 'localhost', 1234) == false )
    -- connect faile
    local con = 'not set con'
    asio.spawn_light_thread(function()
        con = asio.connect('0.0.0.1', '1234')
    end)
    asio.run()
    assert(con == nil, con)

    -- server
    function connection_th(con)
        --print('server')
        local data, err = con:read(5)
        --print('server', data, 'readed', e)
        assert(data == 'ping1' or data == 'ping2' or data == 'ping3')
        con:write(data .. '-pong')
        con:close()
    end

    local s = asio.server('127.0.0.1', 31234, function(con)
        asio.spawn_light_thread(connection_th, con)
    end)
    local total =0
    local test_async = 0
    local ping_send = function(text)
        --print('client', text)
        local con, e = asio.connect('localhost', '31234')
        assert(con, e)
        --print('client', text, 'conned', e)
        local ok, e = con:write(text)
        local data, err = con:read_some()
        assert(data == 'ping1-pong' or data == 'ping2-pong' or data == 'ping3-pong')
        -- test read_some err
        local data, err = con:read_some()
        assert(#data == 0)
        assert(err == 'End of file')
        -- close and destory
        con:close()

        --test sleep
        test_async = test_async + 1
        local beg = os.time()
        asio.sleep(1)
        assert((os.time() - beg) >= 0.99, os.time() - beg)
        assert(test_async == 3, test_async)

        total = total + 1
        if total ==3 then
            asio.destory_server(s)
            s = nil
        end
    end
    asio.spawn_light_thread(ping_send, 'ping1')
    asio.spawn_light_thread(ping_send, 'ping2')
    asio.spawn_light_thread(ping_send, 'ping3')
    asio.run()

end io.write(' \t\t[OK]\n')

--bench
do io.write('---- C Asio Bench ----')

    --benchmark
    local connects = 10
    local sends = 1000
    local con_first = nil --test close crash
    local function client_bench(i)
        local con, e = asio.connect('localhost', '31234')
        if i == 1 then
            con_first = con
            con = nil
            local a,b=con_first:read(500)
            return
        end
        for i=1,sends do
            con:write('123456789|123456789|123456789|123456789|123456789|')
            con:read(50)
        end
        con:close()
        if i == 2 then
            con_first:close()
            local c = con_first.cpoint
            con_first = 1
            collectgarbage('collect')
        end
    end
    local total = 0
    local s
    local function server_bench(con)
        for i=1,sends do
            con:read(50)
            con:write('123456789|123456789|123456789|123456789|123456789|')
            total = total + 1
        end
        con:close()
        if total == sends*connects then
            asio.destory_server(s)
        end
    end
    s = asio.server('127.0.0.1', 31234, function(con)
        asio.spawn_light_thread(server_bench, con)
    end)
    for i = 1,connects do
        asio.spawn_light_thread(client_bench, i)
    end
    asio.run()

end io.write(' \t\t[OK]\n')

--tproxy test
if ffi.os ~= "Windows" then io.write('---- TPROXY Test ----')

    --set iptable
    -- os.execute("iptables -t mangle -N TESTLUAASIO")
    -- os.execute("iptables -t mangle -A TESTLUAASIO -p tcp --dport 21234 -j TPROXY --on-port 31234 --tproxy-mark 0x07")
    -- os.execute("iptables -t mangle -A PREROUTING -p tcp -j TESTLUAASIO")

    os.execute("iptables -t nat -N TESTLUAASIO")
    os.execute("iptables -t nat -A TESTLUAASIO -p tcp --dport 21234 -j REDIRECT --to-port 31234")
    os.execute("iptables -t nat -A PREROUTING -p tcp -j TESTLUAASIO") --network
    os.execute("iptables -t nat -A OUTPUT -p tcp -j TESTLUAASIO")     --local loopback

    --start server
    local dest_addr_str = 'get original destaddr faild.'
    local function test_origin_ip(con)
        local dest_addr = con:get_original_dst()
        dest_addr_str = asio.addr_to_str(dest_addr)
        --print(asio.addr_to_str(dest_addr))
        con:write('123')
        con:close()
    end
    s = asio.server('0.0.0.0', 31234, function(con)
        asio.spawn_light_thread(test_origin_ip, con)
    end)

    --connect test
    asio.spawn_light_thread(function()
        local con, e = asio.connect('8.8.8.8', '21234')
        con:read(3)
        con:close()
        asio.destory_server(s)
    end)
    asio.run()
    assert(dest_addr_str == '8.8.8.8:21234', dest_addr_str)

    --remove iptable
    os.execute("iptables -t nat -D OUTPUT -p tcp -j TESTLUAASIO >/dev/null 2>&1")
    os.execute("iptables -t nat -D PREROUTING -p tcp -j TESTLUAASIO >/dev/null 2>&1")
    os.execute("iptables -t nat -F TESTLUAASIO >/dev/null 2>&1 && iptables -t nat -X TESTLUAASIO >/dev/null 2>&1")

    -- os.execute("iptables -t mangle -D PREROUTING -p tcp -j TESTLUAASIO >/dev/null 2>&1")
    -- os.execute("iptables -t mangle -F TESTLUAASIO >/dev/null 2>&1 && iptables -t mangle -X TESTLUAASIO >/dev/null 2>&1")


io.write(' \t\t[OK]\n') end


print('All Tests passed.')