local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'WikkaWiki' );
close DATA;

__DATA__
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
~- one
~- two
~- three
++++
ul (nested)
<ul>
  <li>one
    <ul>
      <li>one.one</li>
      <li>one.two</li>
      <li>one.three</li>
    </ul>
  </li>
  <li>two
    <ul>
      <li>two.one</li>
      <li>two.two</li>
    </ul>
  </li>
  <li>three</li>
  <li>four</li>
</ul>
++
~- one
~~- one.one
~~- one.two
~~- one.three
~- two
~~- two.one
~~- two.two
~- three
~- four
++++
ol
<ol>
  <li>one
  <li>two
  <li>three
</ol>
++
~1) one
~1) two
~1) three
++++
ol (nested)
<ol>
  <li>one
    <ol>
      <li>one.one</li>
      <li>one.two</li>
      <li>one.three</li>
    </ol>
  </li>
  <li>two
    <ol>
      <li>two.one</li>
      <li>two.two</li>
    </ol>
  </li>
  <li>three</li>
  <li>four</li>
</ol>
++
~1) one
~~1) one.one
~~1) one.two
~~1) one.three
~1) two
~~1) two.one
~~1) two.two
~1) three
~1) four
++++
ul/ol (nested)
<ul>
  <li>one
    <ol>
      <li>one.one</li>
      <li>one.two</li>
      <li>one.three</li>
    </ol>
  </li>
  <li>two
    <ol>
      <li>two.one</li>
      <li>two.two</li>
    </ol>
  </li>
  <li>three</li>
  <li>four</li>
</ul>
++
~- one
~~1) one.one
~~1) one.two
~~1) one.three
~- two
~~1) two.one
~~1) two.two
~- three
~- four
++++
table
<table border="1" class="thingy">
  <tr>
    <td>one</td>
    <td><em>two</em></td>
    <td>three</td>
  </tr>
  <tr>
    <td>four</td>
    <td>five</td>
    <td><b>six</b></td>
  </tr>
</table>
++
|| one || //two// || three ||
|| four || five || **six** ||
++++
image (internal)
<img src="images/logo.png" alt="Logo" title="Our logo" />
++
{{image alt="Logo" title="Our logo" src="images/logo.png"}}
++++
image (external)
<img src="http://www.example.com/logo.png" alt="Logo" title="Example logo" />
++
{{image alt="Logo" title="Example logo" src="http://www.example.com/logo.png"}}
