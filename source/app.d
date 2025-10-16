import core.runtime;
import std.stdio;
import powders.entry;
import colorize;

extern(C) void main()
{
	version(Windows)
	{
		import core.sys.windows.windows;

		SetConsoleCP(65_001);
		SetConsoleOutputCP(65_001);
	}
	dMain();
}


void dMain()
{
	Runtime.initialize();
	try
	{
		powdersMain();
	}
	catch(Throwable ex) // no, that's a good idea because we terminate our programm immediately
	{
		cwriteln("Unhandled error or exception: ".color(fg.red), ex.msg.color(fg.red));
		cwriteln("Stack trace:\n".color(fg.red));

		foreach(i, info; ex.info)
		{
			string strInfo = cast(string) info[0..$];
			
			if(i % 2 == 0)
			{
				cwriteln(strInfo.color(fg.red));
			}
			else
			{
				cwriteln(strInfo.color(fg.yellow));
			}
		}
	}
	finally
	{
		Runtime.terminate();
	}
}