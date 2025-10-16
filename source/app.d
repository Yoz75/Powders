import std.stdio;
import powders.entry;
import core.runtime;

extern(C) void main()
{
	dMain();
}


void dMain()
{
	Runtime.initialize();
	try
	{
		powdersMain();
	}
	catch(Throwable ex)
	{
		writeln("Unhandled error or exception: " ~ ex.msg);
	}
	finally
	{
		Runtime.terminate();
	}
}