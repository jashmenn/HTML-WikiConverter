local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'WakkaWiki' );
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
	- one 
	- two 
	- three
++++
ol
<ol>
  <li>one
  <li>two
  <li>three
</ol>
++
	1) one 
	2) two 
	3) three
++++
nested list
<ul>
  <li> one
    <ol> <li>1 <li>2 <li>3 </ol>
  </li>
  <li> two
    <ol> <li>1 <li>2 <li>3 </ol>
  </li>
  <li>three
</ul>  
++
	- one 
		1) 1 
		2) 2 
		3) 3 
	- two 
		1) 1 
		2) 2 
		3) 3 
	- three
++++
image
<img src="http://www.test.com/image.png" />
++
""<img src="http://www.test.com/image.png" />""
++++
image (w/ attrs)
<img src="http://www.test.com/image.png" alt="my image" width="50" height="45" />
++
""<img src="http://www.test.com/image.png" alt="my image" width="50" height="45" />""
++++
image (strip attrs)
<img src="http://www.test.com/image.png" alt="my image" width="50" height="45" onclick="alert('hello')" />
++
""<img src="http://www.test.com/image.png" alt="my image" width="50" height="45" />""
++++
image (escape attrs)
<img src="http://www.test.com/image.png" alt="my < thing" />
++
""<img src="http://www.test.com/image.png" alt="my &lt; thing" />""
