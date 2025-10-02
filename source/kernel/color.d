module kernel.color;

/// 0xFFFFFF color
enum Color white = Color(255, 255, 255);
enum Color black = Color(0, 0, 0);
enum Color red = Color(255, 0, 0);
enum Color green = Color(0, 255, 0);
enum Color blue = Color(0, 0, 255);

public struct Color
{
public:
    ubyte r, g, b, a;    

    this(ubyte r, ubyte g, ubyte b, ubyte a = 255)
    {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
}