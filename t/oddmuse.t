local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'Oddmuse', wiki_uri => 'http://www.test.com/wiki/', camel_case => 1 );
close DATA;

__DATA__
bold
<b>bold</b>
++
*bold*
++++
strong
<strong>strong</strong>
++
*strong*
++++
italic
<i>italic</i>
++
/italic/
++++
em
<em>em</em>
++
~em~
++++
underline
<u>underline</u>
++
_underline_
++++
image
<img src="http://www.test.com/image.png" />
++
http://www.test.com/image.png
++++
external link (free link)
<a href="http://www.google.com">http://www.google.com</a>
++
http://www.google.com
++++
external link (alt text)
<a href="http://www.google.com">Google</a>
++
[http://www.google.com Google]
++++
internal link
<a href="http://www.test.com/wiki/Markup_Extension">Markup Extension</a>
++
[[Markup Extension]]
++++
internal link (alt text)
<a href="http://www.test.com/wiki/Markup_Extension">markup ext</a>
++
[[Markup Extension|markup ext]]
++++
internal link (camel case)
<a href="http://www.test.com/wiki/CamelCaseLink">CamelCaseLink</a>
++
CamelCaseLink
++++
table
<table>
<tr><th>foo</th><th>bar</th><th>baz</th></tr>
<tr><td>one</td><td>two</td><td>three</td></tr>
<tr><td>1</td><td>2</td><td>3</td></tr>
</table>
++
||foo ||bar ||baz ||
||one ||two ||three ||
||1 ||2 ||3 ||
++++
table (align)
<table>
<tr><th align="left">foo</th><th align="center">bar</th><th align="right">baz</th></tr>
<tr><td align="right">one</td><td align="left">two</td><td align="center">three</td></tr>
<tr><td align="center">1</td><td align="right">2</td><td align="left">3</td></tr>
</table>
++
||foo || bar || baz||
|| one||two || three ||
|| 1 || 2||3 ||
++++
table (colspan)
<table>
<tr><th colspan="2" align="left">foo</th><th align="center">bar</th></tr>
<tr><td align="right">one</td><td align="left">two</td><td align="center">three</td></tr>
<tr><td colspan="3" align="center">1</td></tr>
</table>
++
||||foo || bar ||
|| one||two || three ||
|||||| 1 ||
++++
list (ul)
<ul>
  <li>one
  <li>two
  <li>three
</ul>
++
* one 
* two 
* three
++++
list (ol)
<ol>
  <li>one
  <li>two
  <li>three
</ol>
++
* one 
* two 
* three
++++
list (nested ul/ul)
<ul>
  <li>1
    <ul>
      <li>1.a
      <li>1.b
    </ul>
  </li>
  <li>2
  <li>3
    <ul>
      <li>3.a
      <li>3.b
    </ul>
  </li>
</ul>
++
* 1 
** 1.a 
** 1.b  
* 2 
* 3 
** 3.a 
** 3.b
++++
list (nested ul/ol)
<ul>
  <li>1
    <ol>
      <li>1.a
      <li>1.b
    </ol>
  </li>
  <li>2
  <li>3
    <ol>
      <li>3.a
      <li>3.b
    </ol>
  </li>
</ul>
++
* 1 
** 1.a 
** 1.b 
* 2 
* 3 
** 3.a 
** 3.b
++++
list (nested ol/ul)
<ol>
  <li>1
    <ul>
      <li>1.a
      <li>1.b
    </ul>
  </li>
  <li>2
  <li>3
    <ul>
      <li>3.a
      <li>3.b
    </ul>
  </li>
</ol>
++
* 1 
** 1.a 
** 1.b 
* 2 
* 3 
** 3.a 
** 3.b
