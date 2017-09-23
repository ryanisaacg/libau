module dgt.texture;

import derelict.sdl2.sdl, derelict.sdl2.image;
import derelict.opengl;
import dgt.array : Array;
import dgt.io;
import dgt.geom : Vector, Rectangle;
import dgt.util : nullTerminate, nextline, parsePositiveInt, trimLeft;

import std.path : dirName;
import std.string : indexOf;

import core.stdc.string, core.stdc.stdio, core.stdc.stdlib;

///The format of each pixel in byte order
enum PixelFormat : GLenum
{
    RGB = GL_RGB,
    RGBA = GL_RGBA,
    BGR = GL_BGR,
    BGRA = GL_BGRA
}

/**
A drawable texture which can also be a region of a larger texture
*/
struct Texture
{
    package uint id;
    private:
    int width, height;
    Rectangle region;
    package bool rotated = false;

    @disable this();


    @nogc nothrow public:
    ///Create a Texture from data in memory
    this(ubyte* data, int w, int h, PixelFormat format)
    {
        GLuint texture;
        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, format, GL_UNSIGNED_BYTE, data);
        glGenerateMipmap(GL_TEXTURE_2D);
        id = texture;
        width = w;
        height = h;
        region = Rectangle(0, 0, w, h);
    }
    
    //Mock or don't mock the constructor
    version(unittest)
    {
        @nogc nothrow this(string name)
        {
        }
    }
    else
    {
        ///Load a texture from a file with a given path
        this(string name)
        {
            auto nameNullTerminated = nullTerminate(name);
            SDL_Surface* surface = IMG_Load(nameNullTerminated.ptr);
            nameNullTerminated.destroy();
            if (surface == null)
            {
                auto buffer = IMG_GetError();
                println("Image loading error: ", buffer[0..strlen(buffer)]);
                this(null, 0, 0, PixelFormat.RGB);
            }
            else
            {
                this(surface);
                SDL_FreeSurface(surface);
            }
        }
    }

    ///Load a texture from an SDL_Surface in memory
    this(SDL_Surface* sur)
    {
        PixelFormat format;
        if(sur.format.BytesPerPixel == 4)
            if(sur.format.Rmask == 0x000000ff)
                format = PixelFormat.RGBA;
            else
                format = PixelFormat.BGRA;
        else
            if(sur.format.Rmask == 0x000000ff)
                format = PixelFormat.RGB;
            else
                format = PixelFormat.BGR;
        this(cast(ubyte*)sur.pixels, sur.w, sur.h, format);
    }

    pure:
    ///Get a texture that represents a region of a larger texture
    Texture getSlice(Rectangle region, bool rotated = false) const
    {
        Texture tex = this;
        tex.region = Rectangle(this.region.x + region.x,
                this.region.y + region.y, region.width, region.height);
        tex.rotated = rotated;
        return tex;
    }
    ///Get the width of the source image
    @property int sourceWidth() const { return width; }
    ///Get the height of the source image
    @property int sourceHeight() const { return height; }
    ///Get the size of the texture's region
    @property Rectangle size() const { return region; }
}

struct Atlas
{
    Array!Texture pages, regions;
    Array!string regionNames;

    @disable this();

    nothrow @nogc:
    this(string atlasPath)
    {
        pages = Array!Texture(2);
        regions = Array!Texture(32);
        regionNames = Array!string(32);
        auto terminated = nullTerminate(atlasPath);
        FILE* file = fopen(terminated.ptr, "r".ptr);
        terminated.destroy();
        if(file == null)
        {
            println("Failed to load texture atlas ", atlasPath);
            return;
        }
        auto contents = Array!char(1024);
        int next;
        //Read the file into memory
        while((next = fgetc(file)) != EOF)
            contents.add(cast(char)next);
        string text = contents.array;
        auto texturePath = Array!char(atlasPath.length * 2);
        scope(exit) texturePath.destroy();
        while(text.length > 0)
        {
            texturePath.clear();
            string relativeTexturePath = text.nextline(text);
            const atlasPathDir = dirName(atlasPath);
            foreach(character; atlasPathDir)
                texturePath.add(character);
            texturePath.add('/');
            foreach(character; relativeTexturePath)
                texturePath.add(character);
            const page = Texture(texturePath.array);
            pages.add(page);
            text.nextline(text); //ignore the line telling the size
            text.nextline(text); //ignore the line telling the format
            text.nextline(text); //ignore the line telling the filter
            text.nextline(text); //ignore the line telling the repeat
            auto regionName = text.nextline(text);
            do
            {
                auto propertyLine = text.nextline(text);
                bool rotate;
                Vector position, size;
                while(propertyLine.length > 0 && propertyLine[0] == ' ')
                {
                    propertyLine = propertyLine.trimLeft;
                    const colonIndex = propertyLine.indexOf(':');
                    const property = propertyLine[0..colonIndex];
                    const value = propertyLine[colonIndex + 1..propertyLine.length].trimLeft;
                    if(property == "rotate")
                    {
                        rotate = (value == "true");
                    } else if(property == "xy")
                    {
                        const x = parsePositiveInt(value[0..value.indexOf(',')]);
                        const y = parsePositiveInt(value[value.indexOf(',') + 1..value.length].trimLeft);
                        position = Vector(x, y);
                    } else if(property == "size")
                    {
                        const x = parsePositiveInt(value[0..value.indexOf(',')]);
                        const y = parsePositiveInt(value[value.indexOf(',') + 1..value.length].trimLeft);
                        size = Vector(x, y);
                    }
                    propertyLine = text.nextline(text);
                }
                const region = Rectangle(position, size);
                println(region);
                regions.add(page.getSlice(region, rotate));
                regionNames.add(regionName);
                regionName = propertyLine;
            } while(regionName.length > 0);
        }
        contents.destroy();
    }

    @nogc:
    pure Texture opIndex(in string regionName, Texture notFound = Texture(null, 0, 0, PixelFormat.RGB)) const
    {
        for(uint i = 0; i < regionNames.length; i++)
            if(regionNames[i] == regionName)
                return regions[i];
        return notFound;
    }

    void destroy()
    {
        pages.destroy();
        regions.destroy();
    }
}

unittest
{
    auto atlas = Atlas("test.atlas");
    assert(atlas.regionNames[0] == "bg-dialog");
    assert(atlas.regionNames[1] == "bg-dialog2");
    assert(atlas.regions[0].size.topLeft == Vector(519, 223));
    assert(atlas.regions[0].size.size == Vector(21, 42));
    assert(atlas.regions[1].rotated);
}
