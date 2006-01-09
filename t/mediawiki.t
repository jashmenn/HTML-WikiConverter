local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'MediaWiki', wiki_uri => 'http://www.test.com/wiki/' );
close DATA;

__DATA__
external link
<p><a href="http://example.com">[http://example.com]</a></p>
++
[http://example.com <nowiki>[http://example.com]</nowiki>]
++++
nowiki template
<p>mark stubs with {{stub}}</p>
++
<nowiki>mark stubs with {{stub}}</nowiki>
++++
nowiki quoted
<p>what happens to 'quoted text'?</p>
++
what happens to 'quoted text'?
++++
nowiki doubly quoted
<p>how about ''doubly quoted''?</p>
++
<nowiki>how about ''doubly quoted''?</nowiki>
++++
nowiki triply quoted
<p>and '''triply quoted'''?</p>
++
<nowiki>and '''triply quoted'''?</nowiki>
++++
nowiki hr
<p>----</p>
++
<nowiki>----</nowiki>
++++
nowiki ul
<p>* ul</p>
++
<nowiki>* ul</nowiki>
++++
nowiki ol
<p># ol</p>
++
<nowiki># ol</nowiki>
++++
nowiki def
<p>; def</p>
++
<nowiki>; def</nowiki>
++++
nowiki indent
<p>: indent</p>
++
<nowiki>: indent</nowiki>
++++
nowiki internal links
<p>an [[internal]] link</p>
++
<nowiki>an [[internal]] link</nowiki>
++++
nowiki table markup
<p>{|<br />
| table<br />
|}</p>
++
<nowiki>{|</nowiki><br /> | table<br /> |}
++++
nowiki ext link
<p>[http://example.com]</p>
++
<nowiki>[http://example.com]</nowiki>
++++
tr attributes
<html><table><tr align="left" valign="top"><td>ok</td></tr></table></html>
++
{|
|- align="left" valign="top"
| ok
|}
++++
preserve cite
<html><cite id="good">text</cite></html>
++
<cite id="good">text</cite>
++++
preserve var
<html><var id="good">text</var></html>
++
<var id="good">text</var>
++++
preserve blockquote
<html><blockquote cite="something" onclick="alert('hello')">text</blockquote></html>
++
<blockquote cite="something">text</blockquote>
++++
preserve ruby
<html><ruby>text</ruby></html>
++
<ruby>text</ruby>
++++
preserve rb
<html><rb id="ok">text</rb></html>
++
<rb id="ok">text</rb>
++++
preserve rt
<html><rt id="ok" blah="blah">text</rt></html>
++
<rt id="ok">text</rt>
++++
preserve rp
<html><rp id="ok" something="ok" bad="good" class="stuff">text</rp></html>
++
<rp id="ok" class="stuff">text</rp>
++++
preserve div
<html><div id="thing" align="left" bad="good">ok</div></html>
++
<div id="thing" align="left">ok</div>
++++
empty line break
<html><br id="thing"></br></html>
++
<br id="thing" />
++++
br attribs
<html>ok<br id="stuff" class="things" title="ok" style="clear:both" clear="both"></html>
++
ok<br id="stuff" class="things" title="ok" style="clear:both" clear="both" />
++++
wrap in html
<a href="http://google.com">GOOGLE</a><br/>
NewLine
++
[http://google.com GOOGLE]<br /> NewLine
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
underlined
<html><u>underlined</u></html>
++
<u>underlined</u>
++++
strikethrough
<html><s>strike</s></html>
++
<s>strike</s>
++++
deleted
<html><del>deleted text</del></html>
++
<del>deleted text</del>
++++
inserted
<html><ins>inserted</ins></html>
++
<ins>inserted</ins>
++++
span
<html><span>span</span></html>
++
<span>span</span>
++++
strip aname
<html><a name="thing"></a></html>
++

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
**# i
** b
* 2
*: indented
++++
hr
<html><hr /></html>
++
----
++++
br
<html><p>stuff<br />stuff two</p></html>
++
stuff<br />stuff two
++++
div
<html><div>thing</div></html>
++
<div>thing</div>
++++
div w/ attrs
<html><div id="name" class="panel" onclick="popup()">thing</div></html>
++
<div id="name" class="panel">thing</div>
++++
sub
<html><p>H<sub>2</sub>O</p></html>
++
H<sub>2</sub>O
++++
sup
<html><p>x<sup>2</sup></p></html>
++
x<sup>2</sup>
++++
center
<html><center>centered text</center></html>
++
<center>centered text</center>
++++
small
<html><small>small text</small></html>
++
<small>small text</small>
++++
code
<html><code>$name = 'stan';</code></html>
++
<code>$name = 'stan';</code>
++++
tt
<html><tt>tt text</tt></html>
++
<tt>tt text</tt>
++++
font
<html><font color="blue" face="Arial" size="+2">font</font></html>
++
<font size="+2" color="blue" face="Arial">font</font>
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
[[Image:thing.gif]]
++++
table
<table>
  <caption>Stuff</caption>
  <tr>
    <th> Name </th> <td> David </td>
  </tr>
  <tr>
    <th> Age </th> <td> 24 </td>
  </tr>
  <tr>
    <th> Height </th> <td> 6' </td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <td> Nested </td>
          <td> tables </td>
        </tr>
        <tr>
          <td> are </td>
          <td> fun </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
++
{|
|+ Stuff
|-
! Name
| David
|-
! Age
| 24
|-
! Height
| 6'
|-
|
{|
| Nested
| tables
|-
| are
| fun
|}
|}
++++
table w/ attrs
<table border=1 cellpadding=3 bgcolor=#ffffff onclick='alert("alert!")'>
  <caption>Stuff</caption>
  <tr id="first" class="unselected">
    <th id=thing bgcolor=black> Name </th> <td> Foo </td>
  </tr>
  <tr class="selected">
    <th> Age </th> <td>24</td>
  </tr>
  <tr class="unselected">
    <th> <u>Height</u> </th> <td> 6' </td>
  </tr>
</table>
++
{| border="1" cellpadding="3" bgcolor="#ffffff"
|+ Stuff
|- id="first" class="unselected"
! id="thing" bgcolor="black" | Name
| Foo
|- class="selected"
! Age
| 24
|- class="unselected"
! <u>Height</u>
| 6'
|}
++++
table w/ blocks
<table>
  <tr>
    <td align=center>
      <p>Paragraph 1</p>
      <p>Paragraph 2</p>
    </td>
  </tr>
</table>
++
{|
| align="center" |
Paragraph 1

Paragraph 2
|}
++++
strip empty aname
<html><a name="thing"></a> some text</html>
++
some text
++++
wiki link (text == title)
<html><a href="/wiki/Some_wiki_page">Some wiki page</a></html>
++
[[Some wiki page]]
++++
wiki link (text case != title case)
<html><a href="/wiki/Another_page">another page</a></html>
++
[[another page]]
++++
wiki link (text != title)
<html><a href="/wiki/Another_page">some text</a></html>
++
[[Another page|some text]]
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
strip urlexpansion
<html><a href="http://www.google.com">Google</a> <span class=" urlexpansion ">(http://www.google.com)</span></html>
++
[http://www.google.com Google]
++++
strip printfooter
<html><div class="printfooter">Retrieved from blah blah</div></html>
++

++++
strip catlinks
<html><div id="catlinks"><p>Categories: ...</p></div></html>
++

++++
strip editsection
<html>This is <div class="editsection" style="..."><a href="?action=edit&section=1">edit</a></div> great</html>
++
This is

great
++++
escape bracketed urls
<html><p>This is a text node with what looks like an ext. link [http://example.org].</p></html>
++
This is a text node with what looks like an ext. link <nowiki>[http://example.org]</nowiki>.
++++
line with vertical bar
<html><p>| a line with a vertical bar</p></html>
++
<nowiki>| a line with a vertical bar</nowiki>
++++
line that starts with a bang
<html><p>! a line that starts with a bang</p></html>
++
<nowiki>! a line that starts with a bang</nowiki>
++++
line that looks like a section
<html><p>= a line that looks like a section</p></html>
++
<nowiki>= a line that looks like a section</nowiki>
++++
pre-many
<html><pre>preformatted text

with spaces

should produce only one

pre-block</pre></html>
++
 preformatted text
 
 with spaces
 
 should produce only one
 
 pre-block
++++
pre following pre
<html><pre>preformatted text</pre>
<pre>more preformatted text</pre>
<pre>once again</pre></html>
++
 preformatted text

 more preformatted text

 once again
