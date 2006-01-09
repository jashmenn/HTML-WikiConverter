local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'TikiWiki', wiki_uri => 'http://www.test.com/wiki/' );
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
''italic''
++++
em
<em>em</em>
++
''em''
++++
center
<center>center</center>
++
::center::
++++
code
<code>code</code>
++
-+code+-
++++
tt
<tt>tt</tt>
++
-+tt+-
++++
underline
<u>underline</u>
++
===underline===
++++
internal link
<a href="http://www.test.com/wiki/Sandbox">Sandbox</a>
++
((Sandbox))
++++
internal link (camel case)
<a href="http://www.test.com/wiki/SandBox">SandBox</a>
++
SandBox
++++
internal link (alt text)
<a href="http://www.test.com/wiki/Sandbox">my sandbox</a>
++
((Sandbox|my sandbox))
++++
external link
<a href="http://www.google.com">http://www.google.com</a>
++
[http://www.google.com]
++++
external link (alt text)
<a href="http://www.google.com">Google</a>
++
[http://www.google.com|Google]
++++
external link (mailto)
<a href="mailto:test@test.com">Test User</a>
++
[mailto:test@test.com|Test User]
++++
image
<img src="http://www.test.com/image.png" />
++
{img src=http://www.test.com/image.png}
++++
image (w/ attrs)
<img src="http://www.test.com/image.png" width="10" height="20" />
++
{img src=http://www.test.com/image.png width=10 height=20}
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
# one
# two
# three
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
      <li>3.c
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
** 3.c
++++
list (nested ul/ol)
<ul>
  <li>one
    <ol><li>1<li>2<li>3</ol>
  <li>two
  <li>three
    <ol><li>1<li>2<li>3</ol>
  </li>
</ul>
++
* one
## 1
## 2
## 3
* two
* three
## 1
## 2
## 3
++++
dl/dt/dd
<dl><dt>term</dt><dd>definition</dd></dl>
++
; term : definition
