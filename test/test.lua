
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
        print('appected.')
        local data, err = con:read(5)  
        print('server readed:', data, err)        
        con:write(data .. '-pong')  
        con:close()
        print('server closed', data)
    end
    
    local s = asio.server('127.0.0.1', 31234, function(con) 
        asio.spawn_light_thread(connection_th, con) 
    end)

    local ping_send = function(text) 
        local con, e = asio.connect('localhost', '31234')
        local ok, e = con:write(text)
        print('client write ok:', ok, e)
        local data, err = con:read(10)
        print('client readed:', data, err)                
        con:close()
        --asio.stop()
        print('client closed', text)
        if text =='stop_' then
            asio.destory_server(s)
            s = nil
        end
    end
    
    asio.spawn_light_thread(ping_send, 'ping1')
    asio.spawn_light_thread(ping_send, 'ping2')
    asio.spawn_light_thread(ping_send, 'stop_')
    print('run')
    asio.run() 

end io.write(' \t\t[OK]\n')


print('All Tests passed.')