local $/;
require 't/runtests.pl';
runtests( data => <DATA>, dialect => 'PhpWiki' );
close DATA;

__DATA__
pre
<html>
<pre>
Device ID                 : 0
Device Revision           : 0
Firmware Revision         : 1.71
IPMI Version              : 1.0
Manufacturer ID           : 674
Product ID                : 1 (0x0001)
Device Available          : yes
Provides Device SDRs      : yes
Additional Device Support :
    Sensor Device
    SDR Repository Device
    SEL Device
    FRU Inventory Device
    IPMB Event Receiver
Aux Firmware Rev Info     :
    0x00
    0x00
    0x00
    0x00
</pre>
</html>
++
<pre>
Device ID                 : 0
Device Revision           : 0
Firmware Revision         : 1.71
IPMI Version              : 1.0
Manufacturer ID           : 674
Product ID                : 1 (0x0001)
Device Available          : yes
Provides Device SDRs      : yes
Additional Device Support :
    Sensor Device
    SDR Repository Device
    SEL Device
    FRU Inventory Device
    IPMB Event Receiver
Aux Firmware Rev Info     :
    0x00
    0x00
    0x00
    0x00
</pre>
++++
bold
<html><b>bold</b></html>
++
*bold*
++++
italics
<html><i>italics</i></html>
++
_italics_
++++
bold and italics
<html><b>bold</b> and <i>italics</i></html>
++
*bold* and _italics_
++++
bold-italics nested
<html><i><b>bold-italics</b> nested</i></html>
++
_*bold-italics* nested_
++++
strong
<html><strong>strong</strong></html>
++
*strong*
++++
emphasized
<html><em>emphasized</em></html>
++
_emphasized_
++++
one-line phrasals
<html><i>phrasals
in one line</i></html>
++
_phrasals in one line_
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
### i
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
stuff%%%stuff two
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
small
<html><small>small text</small></html>
++
<small>small text</small>
++++
big
<html><big>big text</big></html>
++
<big>big text</big>
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
pre
<html><pre>this
  is
    preformatted
      text</pre></html>
++
<pre>this
  is
    preformatted
      text</pre>
++++
indent
<html><blockquote>indented text</blockquote></html>
++
  indented text
++++
nested indent
<html><blockquote>indented text <blockquote>double-indented</blockquote></blockquote></html>
++
  indented text 
    double-indented
++++
h1
<h1>h1</h1>
++
!!! h1
++++
h2
<h2>h2</h2>
++
!!! h2
++++
h3
<h3>h3</h3>
++
!! h3
++++
h4
<h4>h4</h4>
++
! h4
++++
h5
<h5>h5</h5>
++
! h5
++++
h6
<h6>h6</h6>
++
! h6
++++
img
<html><img src="thing.gif" /></html>
++
http://www.test.com/thing.gif
++++
external links
<html><a href="test.html">thing</a></html>
++
[thing|http://www.test.com/test.html]
++++
definition lists
<html><dl><dt>Some term</dt><dd><p>Embedded <i>formatting</i> is fun<sup>2</sup>!</p><p>Another <strong>formatted</strong> paragraph.</p></dd></dl></html>
++
Some term:

  Embedded _formatting_ is fun<sup>2</sup>!

  Another *formatted* paragraph.
++++
simple tables
<html>
  <table>
    <tr>
      <td> Name </td>
      <td> David </td></tr><tr><td> Age </td>
      <td> 24 </td>
    </tr>
  </table>
</html>
++
Name |
  David
Age |
  24
