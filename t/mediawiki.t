use Test::More tests => 29;
my $v = 1; # verbose mode; set to 1 for more info

BEGIN { use_ok( 'HTML::WikiConverter' ); }

# Simple conversions
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
  "PRE"             => "<PRE> one\n  two\n   three\n\n</PRE>"  => "  one\n   two\n    three\n \n ",
  "CENTER"          => "<CENTER>center</CENTER>"               => "<center>center</center>",
  "SMALL"           => "<SMALL>small</SMALL>"                  => "<small>small</small>",
  "def list"        => "<DL><DT> Def </DT><DD> List</DD></DL>" => "; Def : List",
  "indent"          => "<DL><DD> Indent</DD></DT>"             => ": Indent",
  "double indent"   => "<DL><DD><DL><DD> double indent</DD></DL></DD></DL>" => ":: double indent",
  "unknown tag"     => "<STUFF>what?</STUFF>"                  => "what?",
  "wiki msg"        => "{{msg:stub}}"                          => "<nowiki>{{msg:stub}}</nowiki>",
  "wiki magic"      => "{{NUMBEROFARTICLES}}"                  => "<nowiki>{{NUMBEROFARTICLES}}</nowiki>",
  "wiki substr"     => "{{substr:notenglish}}"                 => "<nowiki>{{substr:notenglish}}</nowiki>",
  "wiki link"       => '<a href="http://en.wikipedia.org/wiki/Place">Place</a>'  => '[[Place]]',
  "wiki link trail" => '<a href="http://en.wikipedia.org/wiki/Place">Places</a>' => '[[Place]]s',
  "wiki link case"  => '<a href="http://en.wikipedia.org/wiki/Place">place</a>'  => '[[place]]',
  "wiki link edit"  => '<a href="http://en.wikipedia.org/w/wiki.phtml?title=Place&action=edit">Place</a>' => '[[Place]]',
  "list"            => "<UL><LI>list</LI></UL>"                => "* list",
  "nested list"     => "<UL><LI> One<UL><LI> Two<UL><LI> Three </LI></UL></LI><LI> Two </LI></UL></LI><LI> One </LI></UL>" => "* One\n** Two\n*** Three\n** Two\n* One",
);

for( my $i = 0; $i < $#html2wiki-1; $i+=3 ) {
  my( $testname, $html, $wiki ) = @html2wiki[$i, $i+1, $i+2];

  my $wc = new HTML::WikiConverter(
    dialect => 'MediaWiki',
    html    => $html,
  );

  if( ! ok( $wc->output eq $wiki, $testname ) and $v ) {
    _debug( $wc, $wiki, $testname );
    my $got = $wc->output;
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
    dialect => 'MediaWiki',
    base_url => 'http://en.wikipedia.org'
  );

  my $testname = "realworld test ".$testnum++;
  if( ! ok( $wc->output eq $want, $testname ) and $v ) {
    _debug( $wc, $want, $testname );
  }
}

sub _debug {
  my( $wc, $wiki, $testname ) = @_;
  my $got = $wc->output;
  my $rend = $wc->rendered_html;

  eval {
    require Text::Diff;
    print Text::Diff::diff( \$got, \$wiki, { STYLE => 'Context' } );
  };

  print "rendered: $rend\n\n" if $v >= 2;
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

<PRE> for( int i = 0; i < 10; i++ ) {
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
--SEPARATOR--
<p>
I'm Big Dave, a 23 year-old <a href="/wiki/UCLA" class='internal' title ="UCLA">UCLA</a> graduate with a bachelor's degree in <a href="/wiki/Physiology" class='internal' title ="Physiology">physiological science</a> and a minor in <a href="/wiki/Cognitive_science" class='internal' title ="Cognitive science">cognitive science</a>. Right now I <a href="/wiki/Computer_programming" class='internal' title ="Computer programming">program</a> for the <a href='http://www.lacoe.edu' class='external' title="http://www.lacoe.edu">LA County Office of Education</a> while I <a href='http://www.gubaba.com/jlisa/' class='external' title="http://www.gubaba.com/jlisa/">research</a> and apply to <a href="/wiki/Medical_school" class='internal' title ="Medical school">medical school</a>. I made my 1000th edit to Wikipedia at 02:23 on <a href="/wiki/April_20" class='internal' title ="April 20">April 20</a>, <a href="/wiki/2004" class='internal' title ="2004">2004</a> <a href='http://en.wikipedia.org/w/wiki.phtml?title=Computed_axial_tomography&diff=0&oldid=3260827' class='external' title="http://en.wikipedia.org/w/wiki.phtml?title=Computed axial tomography&amp;diff=0&amp;oldid=3260827">[1]</a>.


<p>
I am a sensible <a href="/wiki/Christian" class='internal' title ="Christian">Christian</a>, and try to be sensitive to other religions and philosophies (after all, <a href="/wiki/Jesus_Christ" class='internal' title ="Jesus Christ">Jesus Christ</a> was a philosopher).

<p>
My social and political views most closely mirror those of <a href="/wiki/Bill_O%27Reilly_(commentator)" class='internal' title ="Bill O'Reilly (commentator)">Bill O'Reilly</a>: I am conservative with regard to <a href="/wiki/Abortion" class='internal' title ="Abortion">abortion</a> and the <a href="/wiki/First_Amendment" class='internal' title ="First Amendment">establishment clause</a>, but liberal vis-&agrave;-vis <a href="/wiki/Gay_marriage" class='internal' title ="Gay marriage">gay marriage</a> and the decriminalization of <a href="/wiki/Marijuana" class='internal' title ="Marijuana">marijuana</a>.

<p>
I love the concept of Wikipedia, and believe that it is the next Big Thing<sup >&trade;</sup >. That's why I want Wikipedia to be as <a href="/wiki/Wikipedia:Guide_to_Layout" class='internal' title ="Wikipedia:Guide to Layout">presentable</a>, <a href="/wiki/Wikipedia:Accuracy_dispute" class='internal' title ="Wikipedia:Accuracy dispute">accurate</a>, <a href="/wiki/Wikipedia:Neutral_point_of_view" class='internal' title ="Wikipedia:Neutral point of view">NPOV</a>, and <a href="/wiki/Wikipedia:The_perfect_stub_article" class='internal' title ="Wikipedia:The perfect stub article">stub</a>-free as possible. So please don't take it personally if I criticize your edits or mark one of your pages for <a href="/wiki/Wikipedia:Deletion_policy" class='internal' title ="Wikipedia:Deletion policy">deletion</a>.


<p>
I do not believe there should be a <a href='http://tlh.wikipedia.org/' class='external' title="http://tlh.wikipedia.org/">Klingon Wikipedia</a>.

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=2";return false;'><h2><a name="WikiProject_Clinical_medicine"> WikiProject Clinical medicine </a></h2></span>

<p>
Though I'm not a <a href="/wiki/Physician" class='internal' title ="Physician">physician</a>, I would like to see a vast improvement of the medical topics covered by WP. <a href="/wiki/User:Jfdwolff" class='internal' title ="User:Jfdwolff">Jfdwolff</a> introduced the <a href="/wiki/User:Jfdwolff/WikiDoc" class='internal' title ="User:Jfdwolff/WikiDoc">WikiDoc</a> project (now <a href="/wiki/Wikipedia:WikiProject_Clinical_medicine" class='internal' title ="Wikipedia:WikiProject Clinical medicine">WikiProject Clinical medicine</a>), which aims to do just that. The first stage of work is apparently navigational, and includes that insertion of a "blue box" (via {{msg:medicine}}) into medical pages to tie them together.


<p>
Similar blue boxes are needed for articles in the basic sciences, <a href="/wiki/Anatomy" class='internal' title ="Anatomy">anatomy</a>, <a href="/wiki/Physiology" class='internal' title ="Physiology">physiology</a>, etc., so I'll be adding them soon. I'll start with some basic organ systems:

<p>
<table cellpadding=3 cellspacing=0 border=1 style="border-collapse:collapse">
<tr >
<TD bgcolor="#cccccc"> <strong>System</strong>
</TD><TD bgcolor="#cccccc"> <strong>MediaWiki page</strong>
</TD><TD bgcolor="#cccccc"> <strong>Wikitext</strong>

</TD></tr>
<tr >
<TD> <a href="/wiki/Human_anatomy" class='internal' title ="Human anatomy">Human organ systems</a>
</TD><TD> <a href="/wiki/MediaWiki:Organ_systems" class='internal' title ="MediaWiki:Organ systems">MediaWiki:Organ systems</a>
</TD><TD> {{msg:organ_systems}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Cardiovascular_system" class='internal' title ="Cardiovascular system">Cardiovascular system</a>
</TD><TD> <a href="/wiki/MediaWiki:Cardiovascular_system" class='internal' title ="MediaWiki:Cardiovascular system">MediaWiki:Cardiovascular system</a>

</TD><TD> {{msg:cardiovascular_system}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Digestive_system" class='internal' title ="Digestive system">Digestive system</a>
</TD><TD> <a href="/wiki/MediaWiki:Digestive_system" class='internal' title ="MediaWiki:Digestive system">MediaWiki:Digestive system</a>
</TD><TD> {{msg:digestive_system}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Endocrine_system" class='internal' title ="Endocrine system">Endocrine system</a>

</TD><TD> <a href="/wiki/MediaWiki:Endocrine_system" class='internal' title ="MediaWiki:Endocrine system">MediaWiki:Endocrine system</a>
</TD><TD> {{msg:endocrine_system}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Immune_system" class='internal' title ="Immune system">Immune system</a>
</TD><TD> <a href="/wiki/MediaWiki:Immune_system" class='internal' title ="MediaWiki:Immune system">MediaWiki:Immune system</a>
</TD><TD> {{msg:immune_system}}
</TD></tr>
<tr >

<TD> <a href="/wiki/Integumentary_system" class='internal' title ="Integumentary system">Integumentary system</a>
</TD><TD> <a href="/wiki/MediaWiki:Integumentary_system" class='internal' title ="MediaWiki:Integumentary system">MediaWiki:Integumentary system</a>
</TD><TD> {{msg:integumentary_system}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Lymphatic_system" class='internal' title ="Lymphatic system">Lymphatic system</a>
</TD><TD> <a href="/wiki/MediaWiki:Lymphatic_system" class='internal' title ="MediaWiki:Lymphatic system">MediaWiki:Lymphatic system</a>
</TD><TD> {{msg:lymphatic_system}}

</TD></tr>
<tr >
<TD> <a href="/wiki/Muscular_system" class='internal' title ="Muscular system">Muscular system</a>
</TD><TD> <a href="/wiki/MediaWiki:Muscular_system" class='internal' title ="MediaWiki:Muscular system">MediaWiki:Muscular system</a>
</TD><TD> {{msg:muscular_system}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Nervous_system" class='internal' title ="Nervous system">Nervous system</a>
</TD><TD> <a href="/wiki/MediaWiki:Nervous_system" class='internal' title ="MediaWiki:Nervous system">MediaWiki:Nervous system</a>

</TD><TD> {{msg:nervous_system}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Reproductive_system" class='internal' title ="Reproductive system">Reproductive system</a>
</TD><TD> <a href="/wiki/MediaWiki:Reproductive_system" class='internal' title ="MediaWiki:Reproductive system">MediaWiki:Reproductive system</a>
</TD><TD> {{msg:reproductive_system}}
</TD></tr>
<tr >
<TD> <a href="/wiki/Urinary_system" class='internal' title ="Urinary system">Urinary system</a>

</TD><TD> <a href="/wiki/MediaWiki:Urinary_system" class='internal' title ="MediaWiki:Urinary system">MediaWiki:Urinary system</a>
</TD><TD> {{msg:urinary_system}}
</TD></tr></table>


<p>
(If you have particularly strong convictions for or against the addition of these elements, please leave a message for me on my <a href="/wiki/User_talk:Diberri" class='internal' title ="User talk:Diberri">talk page</a>.) These should appear on <a href="/wiki/Wikipedia:MediaWiki_custom_elements" class='internal' title ="Wikipedia:MediaWiki custom elements">Wikipedia:MediaWiki custom elements</a> when complete.

<p>
On a related note, <a href="/wiki/User:Fuelbottle" class='internal' title ="User:Fuelbottle">Fuelbottle</a> has done some great work in creating blue boxes for organs themselves. So now, organs like the <a href="/wiki/Pituitary_gland" class='internal' title ="Pituitary gland">pituitary gland</a> get their own article series box footer. Fuelbottle's ASB work can be seen at <a href="/wiki/User:Fuelbottle/footers" class='internal' title ="User:Fuelbottle/footers">User:Fuelbottle/footers</a> and <a href="/wiki/User:Fuelbottle/boxtest" class='internal' title ="User:Fuelbottle/boxtest">User:Fuelbottle/boxtest</a>.


<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=3";return false;'><h2><a name="Recent_activity"> Recent activity </a></h2></span>

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=4";return false;'><h3><a name="In_progress"> In progress </a></h3></span>

<p>

<ul><li> Writing simple HTML to wikitext converter, available at <a href="http://diberri.dyndns.org/html2wiki.html" class='external' title="http://diberri.dyndns.org/html2wiki.html">http://diberri.dyndns.org/html2wiki.html</a>

</li><li> Requesting permission from <a href='http://adam.com' class='external' title="http://adam.com">Adam.com</a> to use images from the <a href='http://www.nlm.nih.gov/medlineplus/encyclopedia.html' class='external' title="http://www.nlm.nih.gov/medlineplus/encyclopedia.html">MedlinePlus Encyclopedia</a> (As of 5/23/04, there's been no response. I'm assuming permission has been denied.)
</li></ul>

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=5";return false;'><h3><a name="Complete"> Complete </a></h3></span>

<p>

<ul><li> Removed MedlinePlus images from my articles that use them (per <a href="/wiki/User:The_Anome" class='internal' title ="User:The Anome">The Anome</a>'s message to me that these images are copyrighted)
</li></ul>

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=6";return false;'><h2><a name="Significant_contributions"> Significant contributions </a></h2></span>

<p>
Apparently the kids these days like to show off their contributions to Wikipedia. Allow me to jump on the bandwagon. Here are a few of my most significant contributions (either I wrote the article, or it's composed mainly of my text).

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=7";return false;'><h3><a name="Anatomy/physiology"> Anatomy/physiology </a></h3></span>

<p>

<ul><li> <a href="/wiki/Adrenal_gland" class='internal' title ="Adrenal gland">Adrenal gland</a>
</li><li> <a href="/wiki/Cholecystokinin" class='internal' title ="Cholecystokinin">Cholecystokinin</a>
</li><li> <a href="/wiki/Distal_convoluted_tubule" class='internal' title ="Distal convoluted tubule">Distal convoluted tubule</a>

</li><li> <a href="/wiki/Ectopic_pregnancy" class='internal' title ="Ectopic pregnancy">Ectopic pregnancy</a>
</li><li> <a href="/wiki/Fetal_hemoglobin" class='internal' title ="Fetal hemoglobin">Fetal hemoglobin</a>
</li><li> <a href="/wiki/Human_chorionic_gonadotropin" class='internal' title ="Human chorionic gonadotropin">Human chorionic gonadotropin</a>
</li><li> <a href="/wiki/Starvation" class='internal' title ="Starvation">Starvation</a>
</li><li> <a href="/wiki/Umbilical_vein" class='internal' title ="Umbilical vein">Umbilical vein</a>

</li></ul>

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=8";return false;'><h3><a name="Animals"> Animals </a></h3></span>

<p>

<ul><li> <em><a href="/wiki/Aplysia_californica" class='internal' title ="Aplysia californica">Aplysia californica</a></em>
</li><li> <a href="/wiki/Colorado_potato_beetle" class='internal' title ="Colorado potato beetle">Colorado potato beetle</a>

</li><li> <a href="/wiki/Cranwell%27s_horned_frog" class='internal' title ="Cranwell's horned frog">Cranwell's horned frog</a>
</li><li> <a href="/wiki/Jerusalem_cricket" class='internal' title ="Jerusalem cricket">Jerusalem cricket</a>
</li></ul>

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=9";return false;'><h3><a name="Neuroscience"> Neuroscience </a></h3></span>

<p>

<ul><li> <a href="/wiki/Anterior_pituitary" class='internal' title ="Anterior pituitary">Anterior pituitary</a>
</li><li> <a href="/wiki/F_wave" class='internal' title ="F wave">F wave</a>
</li><li> <a href="/wiki/Glial_cell" class='internal' title ="Glial cell">Glial cell</a>
</li><li> <a href="/wiki/Hebbian_theory" class='internal' title ="Hebbian theory">Hebbian theory</a>
</li><li> <a href="/wiki/Long-term_potentiation" class='internal' title ="Long-term potentiation">Long-term potentiation</a>
</li><li> <a href="/wiki/Motoneuron" class='internal' title ="Motoneuron">Motor neuron</a>

</li><li> <a href="/wiki/Posterior_pituitary" class='internal' title ="Posterior pituitary">Posterior pituitary</a>
</li><li> <a href="/wiki/Silent_synapse" class='internal' title ="Silent synapse">Silent synapse</a>
</li></ul>

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=10";return false;'><h3><a name="Pathology"> Pathology </a></h3></span>

<p>

<ul><li> <a href="/wiki/Glucagonoma" class='internal' title ="Glucagonoma">Glucagonoma</a>

</li><li> <a href="/wiki/Mitral_valve_prolapse" class='internal' title ="Mitral valve prolapse">Mitral valve prolapse</a>
</li><li> <a href="/wiki/Patent_ductus_arteriosus" class='internal' title ="Patent ductus arteriosus">Patent ductus arteriosus</a>
</li><li> <a href="/wiki/Swyer_syndrome" class='internal' title ="Swyer syndrome">Swyer syndrome</a>
</li></ul>

<p>

<span onContextMenu='document.location="/w/wiki.phtml?title=User%3ADiberri&amp;action=edit&amp;section=11";return false;'><h3><a name="Other"> Other </a></h3></span>

<p>

<ul><li> <a href="/wiki/Allosteric" class='internal' title ="Allosteric">Allosteric</a>
</li><li> <a href="/wiki/Chemical_oxygen_demand" class='internal' title ="Chemical oxygen demand">Chemical oxygen demand</a>
</li><li> <a href="/wiki/List_of_MCAT_topics" class='internal' title ="List of MCAT topics">List of MCAT topics</a>
</li><li> <a href="/wiki/Lorenzo%27s_oil" class='internal' title ="Lorenzo's oil">Lorenzo's oil</a> (and the <a href="/wiki/Lorenzo%27s_Oil_(movie)" class='internal' title ="Lorenzo's Oil (movie)">movie</a>)

</li><li> <a href="/wiki/Rubrication" class='internal' title ="Rubrication">Rubrication</a>
</li><li> <em><a href="/wiki/Theologico-Political_Treatise" class='internal' title ="Theologico-Political Treatise">Theologico-Political Treatise</a></em>
</li></ul>
--YIELDS--
I'm Big Dave, a 23 year-old [[UCLA]] graduate with a bachelor's degree in [[Physiology|physiological science]] and a minor in [[cognitive science]]. Right now I [[Computer programming|program]] for the [http://www.lacoe.edu LA County Office of Education] while I [http://www.gubaba.com/jlisa/ research] and apply to [[medical school]]. I made my 1000th edit to Wikipedia at 02:23 on [[April 20]], [[2004]] [http://en.wikipedia.org/w/wiki.phtml?title=Computed_axial_tomography&diff=0&oldid=3260827].

I am a sensible [[Christian]], and try to be sensitive to other religions and philosophies (after all, [[Jesus Christ]] was a philosopher).

My social and political views most closely mirror those of [[Bill O'Reilly (commentator)|Bill O'Reilly]]: I am conservative with regard to [[abortion]] and the [[First Amendment|establishment clause]], but liberal vis-&agrave;-vis [[gay marriage]] and the decriminalization of [[marijuana]].

I love the concept of Wikipedia, and believe that it is the next Big Thing<sup>&acirc;&#132;&cent;</sup>. That's why I want Wikipedia to be as [[Wikipedia:Guide to Layout|presentable]], [[Wikipedia:Accuracy dispute|accurate]], [[Wikipedia:Neutral point of view|NPOV]], and [[Wikipedia:The perfect stub article|stub]]-free as possible. So please don't take it personally if I criticize your edits or mark one of your pages for [[Wikipedia:Deletion policy|deletion]].

I do not believe there should be a [http://tlh.wikipedia.org/ Klingon Wikipedia].

== WikiProject Clinical medicine ==

Though I'm not a [[physician]], I would like to see a vast improvement of the medical topics covered by WP. [[User:Jfdwolff|Jfdwolff]] introduced the [[User:Jfdwolff/WikiDoc|WikiDoc]] project (now [[Wikipedia:WikiProject Clinical medicine|WikiProject Clinical medicine]]), which aims to do just that. The first stage of work is apparently navigational, and includes that insertion of a "blue box" (via <nowiki>{{msg:medicine}}</nowiki>) into medical pages to tie them together.

Similar blue boxes are needed for articles in the basic sciences, [[anatomy]], [[physiology]], etc., so I'll be adding them soon. I'll start with some basic organ systems:

{| cellpadding="3" cellspacing="0" border="1" style="border-collapse:collapse"
|- 
| bgcolor="#cccccc" | '''System'''
| bgcolor="#cccccc" | '''MediaWiki page'''
| bgcolor="#cccccc" | '''Wikitext'''
|- 
| [[Human anatomy|Human organ systems]]
| [[MediaWiki:Organ systems]]
| <nowiki>{{msg:organ_systems}}</nowiki>
|- 
| [[Cardiovascular system]]
| [[MediaWiki:Cardiovascular system]]
| <nowiki>{{msg:cardiovascular_system}}</nowiki>
|- 
| [[Digestive system]]
| [[MediaWiki:Digestive system]]
| <nowiki>{{msg:digestive_system}}</nowiki>
|- 
| [[Endocrine system]]
| [[MediaWiki:Endocrine system]]
| <nowiki>{{msg:endocrine_system}}</nowiki>
|- 
| [[Immune system]]
| [[MediaWiki:Immune system]]
| <nowiki>{{msg:immune_system}}</nowiki>
|- 
| [[Integumentary system]]
| [[MediaWiki:Integumentary system]]
| <nowiki>{{msg:integumentary_system}}</nowiki>
|- 
| [[Lymphatic system]]
| [[MediaWiki:Lymphatic system]]
| <nowiki>{{msg:lymphatic_system}}</nowiki>
|- 
| [[Muscular system]]
| [[MediaWiki:Muscular system]]
| <nowiki>{{msg:muscular_system}}</nowiki>
|- 
| [[Nervous system]]
| [[MediaWiki:Nervous system]]
| <nowiki>{{msg:nervous_system}}</nowiki>
|- 
| [[Reproductive system]]
| [[MediaWiki:Reproductive system]]
| <nowiki>{{msg:reproductive_system}}</nowiki>
|- 
| [[Urinary system]]
| [[MediaWiki:Urinary system]]
| <nowiki>{{msg:urinary_system}}</nowiki>
|}

(If you have particularly strong convictions for or against the addition of these elements, please leave a message for me on my [[User talk:Diberri|talk page]].) These should appear on [[Wikipedia:MediaWiki custom elements]] when complete.

On a related note, [[User:Fuelbottle|Fuelbottle]] has done some great work in creating blue boxes for organs themselves. So now, organs like the [[pituitary gland]] get their own article series box footer. Fuelbottle's ASB work can be seen at [[User:Fuelbottle/footers]] and [[User:Fuelbottle/boxtest]].

== Recent activity ==

=== In progress ===

* Writing simple HTML to wikitext converter, available at http://diberri.dyndns.org/html2wiki.html
* Requesting permission from [http://adam.com Adam.com] to use images from the [http://www.nlm.nih.gov/medlineplus/encyclopedia.html MedlinePlus Encyclopedia] (As of 5/23/04, there's been no response. I'm assuming permission has been denied.)

=== Complete ===

* Removed MedlinePlus images from my articles that use them (per [[User:The Anome|The Anome]]'s message to me that these images are copyrighted)

== Significant contributions ==

Apparently the kids these days like to show off their contributions to Wikipedia. Allow me to jump on the bandwagon. Here are a few of my most significant contributions (either I wrote the article, or it's composed mainly of my text).

=== Anatomy/physiology ===

* [[Adrenal gland]]
* [[Cholecystokinin]]
* [[Distal convoluted tubule]]
* [[Ectopic pregnancy]]
* [[Fetal hemoglobin]]
* [[Human chorionic gonadotropin]]
* [[Starvation]]
* [[Umbilical vein]]

=== Animals ===

* ''[[Aplysia californica]]''
* [[Colorado potato beetle]]
* [[Cranwell's horned frog]]
* [[Jerusalem cricket]]

=== Neuroscience ===

* [[Anterior pituitary]]
* [[F wave]]
* [[Glial cell]]
* [[Hebbian theory]]
* [[Long-term potentiation]]
* [[Motoneuron|Motor neuron]]
* [[Posterior pituitary]]
* [[Silent synapse]]

=== Pathology ===

* [[Glucagonoma]]
* [[Mitral valve prolapse]]
* [[Patent ductus arteriosus]]
* [[Swyer syndrome]]

=== Other ===

* [[Allosteric]]
* [[Chemical oxygen demand]]
* [[List of MCAT topics]]
* [[Lorenzo's oil]] (and the [[Lorenzo's Oil (movie)|movie]])
* [[Rubrication]]
* ''[[Theologico-Political Treatise]]''
