module davincilib.color;

// Import jsonizer, but not kernel.jsonutil because I don't want the library to depend on the kernel
import jsonizer;

/// 0xFFFFFF color
enum Color white = Color(255, 255, 255);
enum Color black = Color(0, 0, 0);
enum Color red = Color(255, 0, 0);
enum Color green = Color(0, 255, 0);
enum Color blue = Color(0, 0, 255);

/// RGBA color. This struct is serializable
public struct Color
{
    mixin JsonizeMe;
public:
    @jsonize ubyte r;
    @jsonize ubyte g;
    @jsonize ubyte b;
    @jsonize ubyte a;    

    this(ubyte r, ubyte g, ubyte b, ubyte a = 255) pure nothrow @nogc const // <-- Eat this.
    {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
}