prettydoc=../../prettydoc/prettydoc
stylesheet=../../prettydoc/prettydoc-templ/html.css

cd "$(dirname "$0")"
cat ../inc/OctoFeed/{NSString+Version.h,NSTask+Relaunch.h,OctoRelease.h,OctoFeed.h} >OctoFeed.h
cp $stylesheet .
$prettydoc --headerdoc-path=/usr/bin/headerdoc2html -f html -S html.css OctoFeed.h
#$prettydoc --headerdoc-path=/usr/bin/headerdoc2html -f asciidoc OctoFeed.h
#$prettydoc --headerdoc-path=/usr/bin/headerdoc2html -f man OctoFeed.h
#$prettydoc --headerdoc-path=/usr/bin/headerdoc2html -f markdown OctoFeed.h
rm OctoFeed.h
