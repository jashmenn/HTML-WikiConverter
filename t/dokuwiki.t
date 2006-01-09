local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'DokuWiki', wiki_uri => 'http://www.test.com/wiki:', camel_case => 1 );
close DATA;

__DATA__
table
<table><tr><td>thing</td></tr></table>
++
| thing |
++++
table (multi-row)
<table>
<tr><td>one</td></tr>
<tr><td>two</td></tr>
</table>
++
| one |
| two |
++++
table (full 1)
<table>
<tr><th class="centeralign" colspan="3">Table with alignment</th></tr>
<tr><td class="rightalign">right</td><td class="centeralign">center</td><td class="leftalign">left</td></tr>
<tr><td class="leftalign">left</td><td class="rightalign">right</td><td class="centeralign">center</td></tr>
<tr><td>xxxxxxxxxxxx</td><td>xxxxxxxxxxxx</td><td>xxxxxxxxxxxx</td></tr>
</table>
++
^  Table with alignment  ^^^
|  right |  center  | left  |
| left  |  right |  center  |
| xxxxxxxxxxxx | xxxxxxxxxxxx | xxxxxxxxxxxx |
++++
table (full 2)
<table>
<tr><th class="leftalign">Heading 1</th><th class="leftalign">Heading 2</th><th class="leftalign">Heading 3</th></tr>
<tr><td class="leftalign">Row 1 Col 1</td><td class="leftalign">Row 1 Col 2</td><td class="leftalign">Row 1 Col 3</td></tr>
<tr><td class="leftalign">Row 2 Col 1</td><td colspan="2">some colspan (note the double pipe)</td></tr>
<tr><td class="leftalign">Row 3 Col 1</td><td class="leftalign">Row 2 Col 2</td><td class="leftalign">Row 2 Col 3</td></tr>
</table>
++
^ Heading 1  ^ Heading 2  ^ Heading 3  ^
| Row 1 Col 1  | Row 1 Col 2  | Row 1 Col 3  |
| Row 2 Col 1  | some colspan (note the double pipe) ||
| Row 3 Col 1  | Row 2 Col 2  | Row 2 Col 3  |
++++
table (full 3)
<table>
<tr><th>name</th><td>foo</td></tr>
<tr><th>age</th><td>3.14</td></tr>
<tr><th>odd</th><td>true</td></tr>
</table>
++
^ name | foo |
^ age | 3.14 |
^ odd | true |
++++
h1
<h1>one</h1>
++
====== one ======
++++
h2
<h2>two</h2>
++
===== two =====
++++
h3
<h3>three</h3>
++
==== three ====
++++
h4
<h4>four</h4>
++
=== four ===
++++
h5
<h5>five</h5>
++
== five ==
++++
h6
<h6>six</h6>
++
== six ==
++++
external image
<img src="http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png" />
++
{{http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png}}
++++
external image (resize width)
<img src="http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png" width="25" />
++
{{http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png?25}}
++++
external image (resize width and height)
<img src="http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png" width="25" height="30" />
++
{{http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png?25x30}}
++++
external image align (left)
<img src="http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png" class="medialeft" />
++
{{http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png }}
++++
external image align (right)
<img src="http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png" class="mediaright" />
++
{{ http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png}}
++++
external image align (center)
<img src="http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png" class="mediacenter" />
++
{{ http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png }}
++++
external image align (center w/ caption)
<img src="http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png" class="mediacenter" alt="Caption" />
++
{{ http://wiki.splitbrain.org/fetch.php?w=&h=&cache=cache&media=wiki%3Adokuwiki-128.png |Caption}}
++++
blockquote
<blockquote>one</blockquote>
++
> one
++++
blockquote (nested)
<blockquote><blockquote>two</blockquote></blockquote>
++
>> two
++++
blockquote (multi-line)
<blockquote>span
single
line</blockquote>
++
> span single line
++++
blockquote (nested multi-line)
<blockquote><blockquote>span
single
line</blockquote></blockquote>
++
>> span single line
++++
blockquote (markup)
<blockquote><b>with</b> <em>fancy
markup</em> that <u>spans
multiple
lines</u></blockquote>
++
> **with** //fancy markup// that __spans multiple lines__
++++
blockquote (nested continuous)
<blockquote>one<blockquote>two</blockquote></blockquote>
++
> one
>> two
++++
blockquote (doubly nested continuous)
<blockquote>one<blockquote>two<blockquote>three</blockquote></blockquote></blockquote>
++
> one
>> two
>>> three
++++
blockquote (linebreak)
<blockquote>line<br />break</blockquote>
++
> line\\ break
++++
blockquote (full)
<blockquote>
 No we shouldn't</blockquote>
<blockquote>
<blockquote>
 Well, I say we should</blockquote>
</blockquote>
<blockquote>
 Really?</blockquote>
<blockquote>

<blockquote>
 Yes!</blockquote>
</blockquote>
<blockquote>
<blockquote>
<blockquote>
 Then lets do it!</blockquote>
</blockquote>
</blockquote>
++
> No we shouldn't

>> Well, I say we should

> Really?

>> Yes!

>>> Then lets do it!
++++
internal link (lcase)
<a href="/wiki:test">test</a>
++
[[test]]
++++
internal link (ucase)
<a href="/wiki:test">TEST</a>
++
[[TEST]]
++++
internal link (camel case)
<a href="/wiki:test">tEsT</a>
++
tEsT
++++
external link (anonymous)
<a href="http://www.test.com">http://www.test.com</a>
++
http://www.test.com
++++
external link (named)
<a href="http://www.test.com">test</a>
++
[[http://www.test.com|test]]
++++
external link (fragment)
<a href="/wiki:syntax#internal">this Section</a>
++
[[syntax#internal|this Section]]
++++
linebreak
line<br />break
++
line\\ break
++++
bold
<b>bold text</b>
++
**bold text**
++++
strong
<strong>strong text</strong>
++
**strong text**
++++
italic
<i>italic text</i>
++
//italic text//
++++
emphasized
<em>em text</em>
++
//em text//
++++
ul
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
ul (nested)
<ul>
  <li>1
    <ul>
      <li>1.a
      <li>1.b
    </ul>
  </li>
  <li>2
  <li>3
</ul>
++
  * 1
    * 1.a
    * 1.b
  * 2
  * 3
++++
ol
<ol>
  <li>one
  <li>two
  <li>three
</ol>
++
  - one
  - two
  - three
++++
ol (nested)
<ol>
  <li>1
    <ol>
      <li>1.a
      <li>1.b
    </ol>
  </li>
  <li>2
  <li>3
</ol>
++
  - 1
    - 1.a
    - 1.b
  - 2
  - 3
++++
ul/ol combo
<ol>
  <li>1
    <ul>
      <li>1.a
      <li>1.b
    </ul>
  </li>
  <li>2
  <li>3
</ol>
++
  - 1
    * 1.a
    * 1.b
  - 2
  - 3
++++
ol/ul combo
<ul>
  <li>1
    <ol>
      <li>1.a
      <li>1.b
    </ol>
  </li>
  <li>2
  <li>3
</ul>
++
  * 1
    - 1.a
    - 1.b
  * 2
  * 3
