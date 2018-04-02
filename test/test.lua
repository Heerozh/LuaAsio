
local asio = require 'asio'

-- test create and remove thread
do print('----Light Thread Test----\n')

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

end print('==Light Thread Test OK!==\n')
