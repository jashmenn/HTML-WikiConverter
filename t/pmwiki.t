use Test::More;

local $/;
my @tests = split /\+\+\+\+\n/, <DATA>;

plan tests => scalar @tests;

use HTML::WikiConverter;
my $wc = new HTML::WikiConverter(
  dialect => 'PmWiki',
  base_uri => 'http://www.test.com',
  wiki_uri => 'http://www.test.com/pmwiki/'
);

foreach my $test ( @tests ) {
  $test =~ s/^(.*?)\n//; my $name = $1;
  my( $html, $wiki ) = split /\+\+/, $test;
  for( $html, $wiki ) { s/^\n+//; s/\n+$// }
  is( $wc->html2wiki($html), $wiki, $name );
}

__DATA__
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
deleted
<html><del>deleted text</del></html>
++
{-deleted text-}
++++
inserted
<html><ins>inserted text</ins></html>
++
{+inserted text+}
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
<html><ul><li>1<ul><li>a<ol><li>i</li></ol></li><li>b</li></ul></li><li>2<dl><dt>foo</dt><dd>bar</dd></dl></li></ul></html>
++
* 1
** a
### i
** b
* 2
:: foo: bar
++++
hr
<html><hr /></html>
++
----
++++
br
<html><p>stuff<br />stuff two</p></html>
++
stuff \\
stuff two
++++
sub
<html><p>H<sub>2</sub>O</p></html>
++
H_2_O
++++
sup
<html><p>x<sup>2</sup></p></html>
++
x^2^
++++
small
<html><small>small text</small></html>
++
-small text-
++++
big
<html><big>big text</big></html>
++
+big text+
++++
code
<html><code>$name = 'stan';</code></html>
++
@@$name = 'stan';@@
++++
tt
<html><tt>tt text</tt></html>
++
@@tt text@@
++++
indent
<html><blockquote>indented text</blockquote></html>
++
->indented text
++++
nested indent
<html><blockquote>stuff 
  <blockquote>double-indented stuff</blockquote>
</blockquote></html>
++
->stuff 
-->double-indented stuff
++++
h1
<h1>h1</h1>
++
! h1
++++
h2
<h2>h2</h2>
++
!! h2
++++
h3
<h3>h3</h3>
++
!!! h3
++++
h4
<h4>h4</h4>
++
!!!! h4
++++
h5
<h5>h5</h5>
++
!!!!! h5
++++
h6
<h6>h6</h6>
++
!!!!!! h6
++++
<html>
<table border="1" width="50%" onclick="alert('hello')">
  <tr><th>First</th><th>Last</th></tr>
  <tr><td>Barney</td><td>Rubble</td></tr>
  <tr><td>Foo</td><td>Bar</td></tr>
</table>
</html>
++
|| border="1" width="50%"
||!First ||!Last ||
||Barney ||Rubble ||
||Foo ||Bar ||
++++
table w/ colspan
<table align='center' border='1' width='50%'>
<tr>
  <th>Table</th>
  <th>Heading</th>
  <th>Example</th>
</tr>
<tr>
  <th align='left'>Left</th>
  <td align='center'>Center</td>
  <td align='right'>Right</td>
</tr>
<tr>
  <td align='left'> A </td>
  <th align='center'> B </th>
  <td align='right'> C </td>
</tr>
<tr>
  <td> </td>
  <td align='center'>single</td>
  <td> </td>
</tr>
<tr>
  <td> </td>
  <td align='center' colspan='2'>multi span</td>
</tr>
</table>
++
|| border="1" width="50%" align="center"
||!Table ||!Heading ||!Example ||
||!Left || Center || Right||
||A ||! B || C||
|| || single || ||
|| || multi span ||||
++++
pre
<html><pre>this
  is pre-
     formatted
  text</pre></html>
++
 this
   is pre-
      formatted
   text
++++
pre w/ formatting
<html><pre>this
  is pre-
     formatted tex<sup>t</sup>
        with <b>special</b> <del>formatting</del></pre></html>
++
 this
   is pre-
      formatted tex^t^
         with '''special''' {-formatting-}
