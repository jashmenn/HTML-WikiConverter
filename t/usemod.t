local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'UseMod' );
close DATA;

__DATA__
line break
<html><p>line 1<br/>line 2</p></html>
++
line 1<br>line 2
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
<html><b><i>bold-italics</i> nested</b></html>
++
'''''bold-italics'' nested'''
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
one-line phrasals
<html><i>phrasals
in one line</i></html>
++
''phrasals in one line''
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
<html><ul><li>1<ul><li>a<ol><li>i</li></ol></li><li>b</li></ul></li><li>2<dl><dd>indented</dd></dl></li></ul></html>
++
* 1
** a
### i
** b
* 2
:: indented
++++
hr
<html><hr /></html>
++
----
++++
code
<html><code>$name = 'stan';</code></html>
++
<tt>$name = 'stan';</tt>
++++
tt
<html><tt>tt text</tt></html>
++
<tt>tt text</tt>
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
indent
<html><dl><dd>indented text</dd></dl></html>
++
: indented text
++++
nested indent
<html><dl><dd>stuff<dl><dd>double-indented</dd></dl></dd></dl></html>
++
: stuff
:: double-indented
++++
h1
<h1>h1</h1>
++
= h1 =
++++
h2
<h2>h2</h2>
++
== h2 ==
++++
h3
<h3>h3</h3>
++
=== h3 ===
++++
h4
<h4>h4</h4>
++
==== h4 ====
++++
h5
<h5>h5</h5>
++
===== h5 =====
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
<html><a href="http://www.test.com">thing</a></html>
++
[http://www.test.com thing]
++++
external links (rel2abs)
<html><a href="thing.html">thing</a></html>
++
[http://www.test.com/thing.html thing]
++++
definition list
<html><dl><dt>term</dt><dd>definition</dd></dl></html>
++
; term : definition
