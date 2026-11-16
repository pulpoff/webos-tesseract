# Tesseract's client for webOS: its sources (as src/Makefile lists them) and ENet's, compiled with
# the webOS toolchain, linked with SDL from prefix/ and the TV's OpenGL ES 3.2 (build.sh runs it).
# Source paths are compiled in relative to tesseract/ (-ffile-prefix-map), not to the build machine.
SRC := $(TESSERACT)/src
VPATH := $(SRC)
CLIENT := shared/crypto shared/geom shared/glemu shared/stream shared/tools shared/zip \
	engine/aa engine/bih engine/blend engine/client engine/command engine/console engine/dynlight \
	engine/grass engine/light engine/main engine/material engine/menus engine/movie engine/normal \
	engine/octa engine/octaedit engine/octarender engine/physics engine/pvs engine/rendergl \
	engine/renderlights engine/rendermodel engine/renderparticles engine/rendersky engine/rendertext \
	engine/renderva engine/server engine/serverbrowser engine/shader engine/sound engine/stain \
	engine/texture engine/ui engine/water engine/webos engine/world engine/worldio \
	game/ai game/client game/entities game/game game/render game/scoreboard game/server \
	game/waypoint game/weapon
ENET := callbacks compress host list packet peer protocol unix
OBJS := $(CLIENT:%=$(OBJ)/%.o) $(ENET:%=$(OBJ)/enet/%.o)

INCLUDES := -I$(SRC)/shared -I$(SRC)/engine -I$(SRC)/game -I$(SRC)/enet/include -I$(PREFIX)/include/SDL2
CXXFLAGS := $(ARCH) -O2 -ffast-math -fomit-frame-pointer -fsigned-char -fno-exceptions -fno-rtti -funwind-tables -Wall \
	-Wno-class-memaccess -Wno-format-overflow -D_REENTRANT -DSDL_DISABLE_ARM_NEON_H -DWEBOS_GLES $(INCLUDES) \
	-ffile-prefix-map=$(TESSERACT)/=tesseract/
CFLAGS := $(ARCH) -O2 -ffile-prefix-map=$(TESSERACT)/=tesseract/ -I$(SRC)/enet/include -DHAS_FCNTL=1 -DHAS_POLL=1 -DHAS_GETADDRINFO=1 \
	-DHAS_GETNAMEINFO=1 -DHAS_GETHOSTBYNAME_R=1 -DHAS_GETHOSTBYADDR_R=1 -DHAS_INET_PTON=1 \
	-DHAS_INET_NTOP=1 -DHAS_MSGHDR_FLAGS=1 -DHAS_SOCKLEN_T=1
LIBS := -L$(PREFIX)/lib -lSDL2_image -lSDL2_mixer -lSDL2 -lGLESv2 -lz -lrt -ldl -lpthread -Wl,-rpath,'$$ORIGIN/lib'

$(OUT): $(OBJS)
	$(CXX) $(ARCH) -o $@ $(OBJS) $(LIBS)

$(OBJ)/enet/%.o: enet/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

$(OBJ)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -MMD -MP -c -o $@ $<

-include $(OBJS:.o=.d)
