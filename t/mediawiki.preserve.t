local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'MediaWiki', minimal => 1, preserve_italic => 1, preserve_bold => 1 );
close DATA;

__DATA__
preserve bold
<b>bold</b>
++
<b>bold</b>
++++
preserve bold w/ attrs
<b id="this">this</b>
++
<b id="this">this</b>
++++
preserve bold w/ bad attrs
<b onclick="takeOverBrowser()">clickme</b>
++
<b>clickme</b>
++++
convert strong
<strong>strong</strong>
++
'''strong'''
++++
both strong/b
<ul>
  <li> <b>bold</b>
  <li> <strong>strong</strong>
</ul>
++
* <b>bold</b>
* '''strong'''
++++
preserve italic
<i>italic</i>
++
<i>italic</i>
++++
preserve italic w/ attrs
<i id="it">italic</i>
++
<i id="it">italic</i>
++++
preserve italic w/ bad attrs
<i onclick="alert('bad!')">clickme</i>
++
<i>clickme</i>
++++
convert em
<em>em</em>
++
''em''
++++
both em/i
<ul>
  <li> <i>italic</i>
  <li> <em>em</em>
</ul>
++
* <i>italic</i>
* ''em''
