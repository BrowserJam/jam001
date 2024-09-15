CFLAGS	 = $(shell pkg-config --cflags sdl2 SDL2_ttf)
LDFLAGS	 = $(shell pkg-config --libs sdl2 SDL2_ttf) -lm
CC		 = clang
IMGUIDIR = imgui
DEPS 	 = utils.h
#DEPS 	+= $(IMGUIDIR)/imconfig.h $(IMGUIDIR)/imgui.h $(IMGUIDIR)/imgui_impl_sdl2.h $(IMGUIDIR)/imgui_impl_sdlrenderer2.h $(IMGUIDIR)/imgui_internal.h $(IMGUIDIR)/imstb_rectpack.h $(IMGUIDIR)/imstb_textedit.h $(IMGUIDIR)/imstb_truetype.h $(IMGUIDIR)/roboto-font.h
SOURCES  = main.c
#SOURCES += $(IMGUIDIR)/imgui.cpp $(IMGUIDIR)/imgui_demo.cpp $(IMGUIDIR)/imgui_draw.cpp $(IMGUIDIR)/imgui_impl_sdl2.cpp $(IMGUIDIR)/imgui_impl_sdlrenderer2.cpp $(IMGUIDIR)/imgui_tables.cpp $(IMGUIDIR)/imgui_widgets.cpp
DEFINES	 = 
OBJ		 = $(addsuffix .o, $(basename $(notdir $(SOURCES))))

#%.o: %.c $(DEPS)
#	$(CC) -c -o $@ $< $(CFLAGS)

%.o: %.c $(DEPS)
	$(CC) -g -O0 -c -o $@ $< $(CFLAGS) $(DEFINES)

#%.o: $(IMGUIDIR)/%.c $(DEPS)
#	$(CXX) -g -O0 -c -o $@ $< $(CFLAGS)

main: $(OBJ)
	$(CC) -g -O0 -o $@ $^ $(LDFLAGS)

.PHONY: clean
clean:
	rm -f $(OBJ) main