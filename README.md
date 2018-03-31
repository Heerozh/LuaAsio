# LuaAsio

***Under construction***

Simple transparent non-blocking, high concurrency I/O for Luajit. 

There are no multithreading and no callbacks. Asynchronous happens when you perform a non-blocking operation.

Lightweight, low resource usage, available for embedded devices.

You need ```Boost.Asio (Header Only) ``` to compile this.

Tested on windows, linux, openwrt.

# Usage

Server side:
```
local asio = require 'asio'

function accept_handler(con)
    -- Issues a synchronous, but non-blocking I/O operation.
    local data = con:read(5)  
    print(data)  

    -- Still non-blocking
    con:write(data .. '-pong')  
    print(data .. '-pong send ok.')

    con:close()
end

local s = asio.server('localhost', 1234, function(con) 
    -- light threads running asynchronously at various I/O operation.
    asio.spawn_light_thread(accept_handler, con) 
end)

-- This event loop is blocked during code execution
asio.run()
```

Client side:
```
local asio = require 'asio'

local ping_send = function(text) 
    local con = asio.connect('localhost', 1234) 
    con:write(text)
    con:read(10)
    con:close()
end

asio.spawn_light_thread(ping_send, 'ping1')
asio.spawn_light_thread(ping_send, 'ping2')
asio.spawn_light_thread(ping_send, 'ping3')
asio.spawn_light_thread(ping_send, 'ping4')

asio.run()
```

You will see server output like this: 

Each line fully printed, but random order.

````
ping1
ping3
ping2
ping3-pong send ok.
ping4
ping1-pong send ok.
ping2-pong send ok.
ping4-pong send ok.
````


# Light Thread & non-blocking 

Your code needs to execute in Light Thread, actually Light Threads are Lua coroutine that all running in one thread, so you don't have to worry about context switching overhead and race conditions.

When goes to a non-blocking operation, the current Light Thread will wait for completion (block), and then it switches to the other available Light Thread to continue execution, or handle new connection. 


# Building

## Windows

## Ubuntu


# Unit Test

# Reference

**holder = asio.server(ip, point)**

Listening port starts accepting connections.

Server are automatically closed when the holder are garbage collected.

----

**conn, err_msg = asio.connect(host, port)**

Connect to the host port.

If there are no errors, return **con(module)**; otherwise, returns **[nil, err_msg(lua str)]**.

----

**data, err_msg = conn:read(size)**

Read binary data of a specified size.

If there are no errors, returns **data(lua str)**; otherwise, returns **[nil, err_msg(lua str)]**.

----

**ok, err_msg = conn:write(data)**

Write the data(lua str) to connection.

If there are no errors, return **true**; otherwise, returns **[nil, err_msg(lua str)]**.

----

**nil = conn:close()**

Close a connection. No returns.


# License

LuaAsio is available under the MIT license.

Copyright (C) 2018, by Jianhao Zhang (Heerozh) (heeroz@gmail.com), All rights reserved.

