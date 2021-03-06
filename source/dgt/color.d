module dgt.color;

import dgt.io;

import derelict.sdl2.sdl : SDL_Color;

/**
Represents a color with 4 floating-point values

The values are clamped between 0 and 1
*/
struct Color
{
    ///The red component
    float r = 0;
    ///The green component
    float g = 0;
    ///The blue component
    float b = 0;
    ///The alpha component
    float a = 1;

	@nogc nothrow:
	void print() const
	{
		dgt.io.print("Color(", r, ", ", g, ", ", b, ", ", a, ")");
	}

	pure:
	SDL_Color opCast() const
	{
		SDL_Color c = SDL_Color(
			cast(ubyte)(255 * r), cast(ubyte)(255 * g), cast(ubyte)(255 * b), cast(ubyte)(255 * a)
		);
		return c;
	}

    static immutable white = Color(1, 1, 1, 1);
    static immutable black = Color(0, 0, 0, 1);
    static immutable red = Color(1, 0, 0, 1);
    static immutable orange = Color(1, 0.5, 0, 1);
    static immutable yellow = Color(1, 1, 0, 1);
    static immutable green = Color(0, 1, 0, 1);
    static immutable cyan = Color(0, 1, 1, 1);
    static immutable blue = Color(0, 0, 1, 1);
    static immutable purple = Color(1, 0, 1, 1);
    static immutable indigo = Color(0.5, 0, 1, 1);
}



unittest
{
    import dgt.io : println;
    println("Should print a color equivalent to white: ", Color.white);
    SDL_Color orangeSDL = cast(SDL_Color)Color.orange;
    assert(orangeSDL.r == 255 && orangeSDL.g == 127 && orangeSDL.b == 0 && orangeSDL.a == 255);
}
