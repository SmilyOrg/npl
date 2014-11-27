haxe build.hxml -neko bin/neko/npl.n
# haxe build.hxml -cpp bin/cpp/

cd bin/neko/
nekotools boot npl.n
cd ../../