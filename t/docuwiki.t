use Test::More;

local $/;
my @tests = split /\+\+\+\+\n/, <DATA>;

plan tests => scalar @tests;

use HTML::WikiConverter;
my $wc = new HTML::WikiConverter(
  dialect => 'DocuWiki',
  base_uri => 'http://www.test.com',
  wiki_uri => 'http://www.test.com/wiki/',
  wrap_in_html => 1
);

foreach my $test ( @tests ) {
  $test =~ s/^(.*?)\n//; my $name = $1;
  my( $html, $wiki ) = split /\+\+/, $test;
  for( $html, $wiki ) { s/^\n+//; s/\n+$// }
  is( $wc->html2wiki($html), $wiki, $name );
}

__DATA__
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
