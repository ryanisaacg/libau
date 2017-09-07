module dgt.tilemap;
import dgt.array, dgt.geom;
import std.math;

/**
A single tile with an arbitrary value and if the tile is solid or not

A solid tile will indicate its square is not empty
*/
struct Tile(T)
{
	T value;
	bool solid;
}

/**
A fixed-size grid of tiles that can be queried
*/
struct Tilemap(T)
{
	static immutable INVALID_TILE = Tile!T(T(), true);

	private Array!(Tile!T) buffer;
	private int size, _width, _height;

	@nogc nothrow public:
    ///Create a tilemap with a given unit width and height and the units for the size of each tile square
	this(in int mapWidth, in int mapHeight, in int size)
	{
		this._width = mapWidth;
		this._height = mapHeight;
		this.size = size;
        buffer = Array!(Tile!T)((width / size) * (height / size));
		for(size_t i = 0; i < width; i += size)
			for(size_t j = 0; j < height; j += size)
				buffer.add(Tile!T(T(), false));
	}

    ///Free the underlying tilemap memory
	void destroy()
	{
		buffer.destroy();
	}

	pure:
    ///Get a tile from a location
	Tile!T opIndex(in int x, in int y) const
	{
		return valid(x, y) ? buffer[(x / size) * height / size + (y / size)] : INVALID_TILE;
	}
    ///Get a tile from a location
    Tile!T opIndex(in Vector!int vec) const { return this[vec.x, vec.y]; }

    ///Set a tile from a location
	ref Tile!T opIndexAssign(in Tile!T tile, in int x, in int y)
	{
		return buffer[(x / size) * height / size + (y / size)] = tile;
	}
    ///Set a tile from a location
    ref Tile!T opIndexAssign(in Tile!T tile, in Vector!int vec) { return this[vec.x, vec.y] = tile; }

	///Checks if a point falls within a tilemap
    bool valid(in int x, in int y) const
	{
		return x >= 0 && y >= 0 && x < width && y < height;
	}
	///Checks if a point falls within a tilemap
    bool valid(in Vector!int vec) const { return valid(vec.x, vec.y); }

    ///Checks if a point is both valid and empty
	bool empty(in int x, in int y) const
	{
		return !this[x, y].solid;
	}
    ///Checks if a point is both valid and empty
    bool empty(in Vector!int vec) const { return empty(vec.x, vec.y); }

    ///Checks of a region is both valid and empty
	bool empty(in int x, in int y, in int width, in int height) const
	{
		for(int i = x; i < x + width; i += size)
			for(int j = y; j < y + height; j += size)
				if(!empty(i, j))
					return false;
		return empty(x + width, y) && empty(x, y + height) && empty(x + width, y + height);
	}
    ///Checks of a region is both valid and empty
    bool empty(in Rectangle!int rect) const { return empty(rect.x, rect.y, rect.width, rect.height); }

    //TODO: Increase resolution of slideContact
    ///Determine the furthest a region can move without hitting a wall
	Vector!int slideContact(in int x, in int y, in int width, in int height, in Vector!int v) const
	{
		if (empty(x + v.x, y + v.y, width, height))
			return v;
		else
		{
            Vector!int attempt = v;
			while (!empty(x + attempt.x, y, width, height))
				attempt.x /= 2;
			while (!empty(x + attempt.x, y + attempt.y, width, height))
				attempt.y /= 2;
			return attempt;
		}
	}
    ///Determine the furthest a region can move without hitting a wall
    Vector!int slideContact(in Rectangle!int rect, in Vector!int vec) const { return slideContact(rect.x, rect.y, rect.width, rect.height, vec); }

    ///The width of the map in units
	@property int width() const { return _width; }
    ///The height of the map in units
	@property int height() const { return _height; }
    ///The size of a tile in units (both width and height)
	@property int tileSize() const { return size; }
}

unittest
{
    Tilemap!int map = Tilemap!int(640, 480, 32);
    map[35, 35] = Tile!int(5, true);
    assert(map[-1, 0].solid);
    assert(!map[35, 0].solid);
    assert(map[35, 35].value == 5);
    auto moved = map.slideContact(300, 5, 32, 32, Vectori(0, -10));
    assert(moved.x == 0 && moved.y == -5);
    moved = map.slideContact(80, 10, 16, 16, Vectori(1, -20));
    assert(moved.x == 1 && moved.y == -10);
    moved = map.slideContact(50, 50, 10, 10, Vectori(20, 30));
    assert(moved.x == 20 && moved.y == 30);
    moved = map.slideContact(600, 10, 30, 10, Vectori(15, 10));
    assert(moved.x == 7 && moved.y == 10);
}
