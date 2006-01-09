local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'MoinMoin' );
close DATA;

__DATA__
add space between [[BR]] and URL
<html><a href="http://example.com">http://example.com</a><br /></html>
++
http://example.com [[BR]]
++++
wrap in html
<a href="http://google.com">GOOGLE</a><br/>
NewLine
++
[http://google.com GOOGLE][[BR]] NewLine
++++
bold
<html><b>bold</b></html>
++
'''bold'''
++++
italics
<html><i>italics</i></html>
++
''italics''
++++
bold and italics
<html><b>bold</b> and <i>italics</i></html>
++
'''bold''' and ''italics''
++++
bold-italics nested
<html><i><b>bold-italics</b> nested</i></html>
++
'''''bold-italics''' nested''
++++
strong
<html><strong>strong</strong></html>
++
'''strong'''
++++
emphasized
<html><em>emphasized</em></html>
++
''emphasized''
++++
underlined
<html><u>text</u></html>
++
__text__
++++
one-line phrasals
<html><i>phrasals
in one line</i></html>
++
''phrasals in one line''
++++
sup
<html>x<sup>2</sup></html>
++
x^2^
++++
sub
<html>H<sub>2</sub>O</html>
++
H,,2,,O
++++
code
<html><code>$name = 'stan';</code></html>
++
`$name = 'stan';`
++++
tt
<html><tt>tt text</tt></html>
++
`tt text`
++++
small
<html>some <small>small</small> text</html>
++
some ~-small-~ text
++++
big
<html>some <big>big</big> text</html>
++
some ~+big+~ text
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
    * 1a
    * 1b
  * 2
++++
nested lists (different types)
<html><ul><li>1<ul><li>a<ol><li>i</li></ol></li><li>b</li></ul></li><li>2</li></ul></html>
++
  * 1
    * a
      1. i
    * b
  * 2
++++
hr
<html><hr /></html>
++
----
++++
pre
<html><pre>this
  is
    preformatted
      text</pre></html>
++
{{{
this
  is
    preformatted
      text
}}}
++++
h1
<h1>h1</h1>
++
== h1 ==
++++
h2
<h2>h2</h2>
++
=== h2 ===
++++
h3
<h3>h3</h3>
++
==== h3 ====
++++
h4
<h4>h4</h4>
++
===== h4 =====
++++
h5
<h5>h5</h5>
++
====== h5 ======
++++
h6
<h6>h6</h6>
++
====== h6 ======
++++
img
<html><img src="thing.gif" /></html>
++
http://www.test.com/thing.gif
++++
external links
<html><a href="test.html">thing</a></html>
++
[http://www.test.com/test.html thing]
++++
external link (plain)
<html><a href="http://www.test.com">http://www.test.com</a></html>
++
http://www.test.com
++++
definition list
<html><dl><dt>cookies</dt><dd>delicious delicacies</dd></dl></html>
++
cookies:: delicious delicacies
++++
simple table
<html><table><tr><td>name</td><td>david</td></tr></table>
++
|| name || david ||
++++
table w/ attrs
<html>
  <table bgcolor="white" width="100%">
    <tr>
      <td colspan=2 id="thing">thing</td>
    </tr>
    <tr>
      <td>next</td>
      <td id="crazy">crazy</td>
    </tr>
  </table>
</html>
++
||<-2 tablestyle="width:100%; background-color:white" id="thing"> thing ||
|| next ||<id="crazy"> crazy ||
