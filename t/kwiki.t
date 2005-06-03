local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'Kwiki', wiki_uri => 'http://www.test.com?' );
close DATA;

__DATA__
bold
<html><b>bold</b></html>
++
*bold*
++++
italics
<html><i>italics</i></html>
++
/italics/
++++
bold and italics
<html><b>bold</b> and <i>italics</i></html>
++
*bold* and /italics/
++++
bold-italics nested
<html><i><b>bold-italics</b> nested</i></html>
++
/*bold-italics* nested/
++++
strong
<html><strong>strong</strong></html>
++
*strong*
++++
emphasized
<html><em>emphasized</em></html>
++
/emphasized/
++++
underlined
<html><u>text</u></html>
++
_text_
++++
strikethrough
<html><s>text</s></html>
++
-text-
++++
one-line phrasals
<html><i>phrasals
in one line</i></html>
++
/phrasals in one line/
++++
paragraph blocking
<html><p>p1</p><p>p2</p></html>
++
p1

p2
++++
lists
<html><ul><li>1</li><li>2</li></ul></html>
++
* 1
* 2
++++
nested lists
<html><ul><li>1<ul><li>1a</li><li>1b</li></ul></li><li>2</li></ul>
++
* 1
** 1a
** 1b
* 2
++++
nested lists (different types)
<html><ul><li>1<ul><li>a<ol><li>i</li></ol></li><li>b</li></ul></li><li>2</li></ul></html>
++
* 1
** a
000 i
** b
* 2
++++
hr
<html><hr /></html>
++
----
++++
br
<html><p>stuff<br />stuff two</p></html>
++
stuff
stuff two
++++
code
<html><code>$name = 'stan';</code></html>
++
[=$name = 'stan';]
++++
tt
<html><tt>tt text</tt></html>
++
[=tt text]
++++
pre
<html><pre>this
  is
    preformatted
      text</pre></html>
++
 this
   is
     preformatted
       text
++++
h1
<h1>h1</h1>
++
= h1
++++
h2
<h2>h2</h2>
++
== h2
++++
h3
<h3>h3</h3>
++
=== h3
++++
h4
<h4>h4</h4>
++
==== h4
++++
h5
<h5>h5</h5>
++
===== h5
++++
h6
<h6>h6</h6>
++
====== h6
++++
img
<html><img src="thing.gif" /></html>
++
http://www.test.com/thing.gif
++++
internal links (camel-case)
<html><a href="?FunTimes">FunTimes</a></html>
++
FunTimes
++++
forced internal links (no camel-case)
<html><a href="?funTimes">funTimes</a></html>
++
[funTimes]
++++
internal links (camel-case w/ diff. text)
<html><a href="?FunTimes">click here</a></html>
++
[click here http:?FunTimes]
++++
external links
<html><a href="test.html">thing</a></html>
++
[thing http://www.test.com/test.html]
++++
external link (plain)
<html><a href="http://www.test.com">http://www.test.com</a></html>
++
http://www.test.com
++++
simple tables
<html><table>
<tr><td> </td><td>Dick</td><td>Jane</td></tr>
<tr><td>height</td><td>72"</td><td>65"</td></tr>
<tr><td>weigtht</td><td>130lbs</td><td>150lbs</td></tr>
</table></html>
++
|   | Dick | Jane  |
| height | 72" | 65"  |
| weigtht | 130lbs | 150lbs  |
++++
table w/ caption
<html><table>
<caption>Caption</caption>
<tr><td> </td><td>Dick</td><td>Jane</td></tr>
<tr><td>height</td><td>72"</td><td>65"</td></tr>
<tr><td>weigtht</td><td>130lbs</td><td>150lbs</td></tr>
</table></html>
++
Caption

|   | Dick | Jane  |
| height | 72" | 65"  |
| weigtht | 130lbs | 150lbs  |
