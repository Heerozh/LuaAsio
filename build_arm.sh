arm-linux-gnueabi-gcc -g -O3 -shared -std=c++11 -fPIC -D_ARM -I./include luaAsio.cpp -lstdc++ -lpthread -o libasio.so 

