CC = xcrun clang
CFLAGS = -fobjc-arc -O2
FRAMEWORKS = -framework Foundation
INCLUDES = -I. \
           -IC2Server/Core \
           -IC2Server/Crypto \
           -IC2Server/Database \
           -IC2Server/Network \
           -IC2Server/Utils
SOURCES = main.m \
          C2Server/Core/C2Server.m \
          C2Server/Core/ClientHandler.m \
          C2Server/Crypto/EncryptionManager.m \
          C2Server/Network/TCPListener.m \
          C2Server/Network/SSLWrapper.m \
          C2Server/Network/HTTPListener.m \
          C2Server/Utils/Logger.m \
          C2Server/Database/DatabaseManager.m \
          C2Server/Core/CommandProcessor.m

all: c2_server

c2_server: $(SOURCES)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^ $(FRAMEWORKS)

clean:
	rm -f c2_server
	rm -rf logs/*.log

run: c2_server
	./c2_server

install:
	mkdir -p /usr/local/bin
	cp c2_server /usr/local/bin/

.PHONY: all clean run install
