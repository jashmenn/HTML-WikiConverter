use Test::More tests => 25;
BEGIN { use_ok( 'HTML::WikiConverter' ); }

# Simple conversions

my $v = 0;

my @html2wiki = (
  "B"               => "<B>bold</B>"                           => "'''bold'''",
  "STRONG"          => "<STRONG>strong</STRONG>"               => "'''strong'''",
  "I"               => "<I>italic</I>"                         => "''italic''",
  "EM"              => "<EM>emphasized</EM>"                   => "''emphasized''",
  "B/I"             => "<B><I>bold/italic</I></B>"             => "'''''bold/italic'''''",
  "I/B"             => "<I><B>italic/bold</B></I>"             => "'''''italic/bold'''''",
  "HR"              => "<HR>"                                  => "----",
  "BR"              => "line<BR>wrap"                          => "line<br />wrap",
  "SUP"             => "x<SUP>2</SUP>"                         => "x<sup>2</sup>",
  "SUB"             => "H<SUB>2</SUB>O"                        => "H<sub>2</sub>O",
  "PRE"             => "<PRE> one\n  two\n   three\n\n</PRE>"  => " one\n  two\n   three\n \n",
  "CENTER"          => "<CENTER>center</CENTER>"               => "<center>center</center>",
  "SMALL"           => "<SMALL>small</SMALL>"                  => "<small>small</small>",
  "def list"        => "<DL><DT> Def </DT><DD> List</DD></DL>" => "; Def : List",
  "indent"          => "<DL><DD> Indent</DD></DT>"             => ": Indent",
  "double indent"   => "<DL><DD><DL><DD> double indent</DD></DL></DD></DL>" => ":: double indent",
  "unknown tag"     => "<STUFF>what?</STUFF>"                  => "what?",
  "nowiki"          => "<NOWIKI><B>bold</B></NOWIKI>"          => "'''bold'''",
  "wiki msg"        => "{{msg:stub}}"                          => "<nowiki>{{msg:stub}}</nowiki>",
  "wiki magic"      => "{{NUMBEROFARTICLES}}"                  => "<nowiki>{{NUMBEROFARTICLES}}</nowiki>",
  "wiki substr"     => "{{substr:notenglish}}"                 => "<nowiki>{{substr:notenglish}}</nowiki>",
  "list"            => "<UL><LI>list</LI></UL>"                => "* list",
  "nested list"     => "<UL><LI> One<UL><LI> Two<UL><LI> Three </LI></UL></LI><LI> Two </LI></UL></LI><LI> One </LI></UL>" => "* One\n** Two\n*** Three\n** Two\n* One",
);

for( my $i = 0; $i < $#html2wiki-1; $i+=3 ) {
  my( $testname, $html, $wiki ) = @html2wiki[$i, $i+1, $i+2];

  my $wc = new HTML::WikiConverter(
    dialect => 'MediaWiki',
    html    => $html,
  );

  ok( $wc->output eq $wiki, $testname );

  if( $v ) {
    my $got = $wc->output;

    print "rendered: ", $wc->rendered_html, "\n\n" if $v >= 2;
    print "got:      [$got]\n\n";
    print "want:     [$wiki]\n\n";
  }
}

local $/ = undef;
my $data = <DATA>;
my @pairs = split '--SEPARATOR--', $data;

my $testnum = 1;
foreach my $pair ( @pairs ) {
  my( $html, $want ) = split '--YIELDS--', $pair;

  $want =~ s/^\s+//;
  $want =~ s/\s+$//;

  my $wc = new HTML::WikiConverter(
    html => $html,
    dialect => 'MediaWiki'
  );

  ok( $wc->output eq $want, "realworld test ".$testnum++ );

  if( $v ) {
    my $got = $wc->output;
    print "got:      [$got]\n\n";
    print "want:     [$want]\n\n";
  }
}

__DATA__
<HTML>
<BODY>

<H2> Basic features </H2>

<H3> Simple formatting </H3>

<P>
<B>Bold</B>, <I>italic</I>, <STRONG>strong</STRONG>, and <EM>emphasized</EM> text.
</P>

<H2> Cool features </H2>

<H3> Supports image thumbnails: </P>

<P>
If an IMG tag is found with a WIDTH attribute that differs from the actual width of the image, then the resulting image markup will contain the "thumb" keyword followed by the thumbnail width
</P>

<IMG SRC="http://www.google.com/images/logo.gif" WIDTH=100 ALT="Google Logo">

<H3> Recognizes DIVs used to align images </H3>

<P>
If an IMG tag (or an IMG contained within an A tag) is the only child element of a DIV that uses STYLE or CLASS to align the image, then the alignment is taken from the DIV and placed in the image markup
</P>

<DIV CLASS="floatright">
<A HREF="/wiki/Image:Progesterone.png" CLASS="image" TITLE="Molecular diagram of progesterone"><IMG BORDER="0" SRC="/upload/a/ac/Progesterone.png" ALT="Molecular diagram of progesterone"></A>
</DIV>

<DIV STYLE="float:right">
<IMG SRC="http://www.google.com/images/logo.gif" WIDTH=100 ALT="Google Logo">
</DIV>

<HR>

<H3> Supports tables </H3>

<P>
Tables are converted into wikitext. Attributes for table tags (TABLE, TR, etc) will be added appropriately to the resulting wiki table markup 
</P>

<TABLE>
  <TR>
    <TH> Name </TH>
    <TH> DOB </TH>
  </TR>
  <TR>
    <TD> David </TD>
    <TD> 1980 </TD>
  </TR>
  <TR>
    <TD> Steve </TD>
    <TD> 1983 </TD>
  </TR>
  <TR>
    <TD> Eric </TD>
    <TD> 1985 </TD>
  </TR>
</TABLE>

<HR>

<H3>Handles lists (nested ones, too!)</H3>

<ul><li> one

<ul><li> two

<ul><li> three
</li></ul>
</li><li> four
</li></ul>
</li><li> five
</li></ul>

<HR>

<H3>Tidies wikitext </H3>

<P>
Attempts to remove ugly (and unnecessary) spacing between chunks of HTML. Text contained within a PRE tag is left untouched 
</P>

<HR>

<H3>Preformatted text</H3>

<PRE>for( int i = 0; i < 10; i++ ) {
  System.out.println( "Java? In a Perl program?" );
}</PRE>

<H2> Limitations </H2>

<UL>
  <LI> Cannot produce wiki tables with Perl heredoc syntax
</UL>

</BODY>
</HTML>
--YIELDS--
== Basic features ==

=== Simple formatting ===

'''Bold''', ''italic'', '''strong''', and ''emphasized'' text. 

== Cool features ==

=== Supports image thumbnails: ===

If an IMG tag is found with a WIDTH attribute that differs from the actual width of the image, then the resulting image markup will contain the "thumb" keyword followed by the thumbnail width 

[[Image:logo.gif|thumb|100px|Google Logo]]

=== Recognizes DIVs used to align images ===

If an IMG tag (or an IMG contained within an A tag) is the only child element of a DIV that uses STYLE or CLASS to align the image, then the alignment is taken from the DIV and placed in the image markup 

[[Image:Progesterone.png|right|Molecular diagram of progesterone]]

[[Image:logo.gif|right|thumb|100px|Google Logo]]

----

=== Supports tables ===

Tables are converted into wikitext. Attributes for table tags (TABLE, TR, etc) will be added appropriately to the resulting wiki table markup 

{| 
|- 
! Name
! DOB
|- 
| David
| 1980
|- 
| Steve
| 1983
|- 
| Eric
| 1985
|}

----

=== Handles lists (nested ones, too!) ===

* one
** two
*** three
** four
* five

----

=== Tidies wikitext ===

Attempts to remove ugly (and unnecessary) spacing between chunks of HTML. Text contained within a PRE tag is left untouched 

----

=== Preformatted text ===

 for( int i = 0; i < 10; i++ ) {
  System.out.println( "Java? In a Perl program?" );
 }

== Limitations ==

* Cannot produce wiki tables with Perl heredoc syntax
