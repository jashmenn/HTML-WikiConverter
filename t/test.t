use Test::More tests => 9;
BEGIN { use_ok( 'HTML::WikiConverter' ); }

# Rudimentary conversion

my @html2wiki = (
  "<B>bold</B>"              => "'''bold'''",
  "<STRONG>strong</STRONG>"  => "'''strong'''",
  "<I>italic</I>"	     => "''italic''",
  "<EM>emphasized</EM>"	     => "''emphasized''",
  "<HR>"		     => "----",
  "<DL><DD>Indent</DD></DT>" => ":Indent",
  "<NOWIKI>nowiki</NOWIKI>"  => "<nowiki>nowiki</nowiki>",
  "<DL><DT> Def </DT><DD> List</DD></DL>" => "; Def : List",
);

for( my $i = 0; $i < $#html2wiki; $i+=2 ) {
  my( $html, $wiki ) = @html2wiki[$i, $i+1];

  my $wc = new HTML::WikiConverter(
    html => $html
  );

  ok( $wc->output eq $wiki, $wiki );
}



