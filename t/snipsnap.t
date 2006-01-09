local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'SnipSnap', wiki_uri => 'http://www.test.com/space/' );
close DATA;

__DATA__
bold
<b>bold</b>
++
__bold__
++++
strong
<strong>strong</strong>
++
__strong__
++++
italic
<i>italic</i>
++
~~italic~~
++++
emphasized
<em>em</em>
++
~~em~~
++++
strike
<strike>strike</strike>
++
--strike--
++++
internal link
<a href="http://www.test.com/space/SnipSnap">SnipSnap</a>
++
[SnipSnap]
++++
internal link (alt text)
<a href="http://www.test.com/space/SnipSnap">link text</a>
++
[link text|SnipSnap]
++++
external link (plain)
<a href="http://www.google.com">http://www.google.com</a>
++
http://www.google.com
++++
external link (alt text)
<a href="http://www.google.com">Google</a>
++
{link:Google|http://www.google.com}
++++
citation
<blockquote>citation</blockquote>
++
{quote}citation{quote}
++++
h1
<h1>h1</h1>
++
1 h1
++++
h2
<h2>h2</h2>
++
1.1 h2
++++
h3
<h3>h3</h3>
++
1.1 h3
++++
h4
<h4>h4</h4>
++
1.1 h4
++++
h5
<h5>h5</h5>
++
1.1 h5
++++
h6
<h6>h6</h6>
++
1.1 h6
++++
linebreak
line<br />break
++
line\\break
++++
hr
<hr />
++
----
++++
tables
<table>
<tr><th>name</th><th>age</th><th>city</th></tr>
<tr><td>foo</td><td>57</td><td>hollywood</td></tr>
<tr><td>bar</td><td>45</td><td>rubble</td></tr>
<tr><td>baz</td><td>39</td><td>hammock</td></tr>
</table>
++
{table}
name | age | city
foo | 57 | hollywood
bar | 45 | rubble
baz | 39 | hammock
{table}
++++
ordered list
<ol>
  <li>one
  <li>two
  <li>three
</ol>
++
1. one
1. two
1. three
++++
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
nested list (ol/ul)
<ol>
  <li>1
    <ul>
      <li>1.a
      <li>1.b
      <li>1.c
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
1. 1
** 1.a
** 1.b
** 1.c
1. 2
1. 3
** 3.a
** 3.b
++++
nested list (ul/ol)
<ul>
  <li>1
    <ol>
      <li>1.a
      <li>1.b
        <ol>
          <li>1.c
        </ol>
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
11. 1.a
11. 1.b
111. 1.c
* 2
* 3
11. 3.a
11. 3.b
