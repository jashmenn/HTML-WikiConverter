use Test::More tests => 6;
BEGIN { use_ok( 'HTML::WikiConverter' ); }

# Rudimentary conversion

my %html2wiki = (
  "<B>bold</B>"             => "'''bold'''",
  "<STRONG>strong</STRONG>" => "'''strong'''",
  "<I>italic</I>"	    => "''italic''",
  "<EM>emphasized</EM>"	    => "''emphasized''",
  "<HR>"		    => "----",
);

while( my( $html, $wiki ) = each %html2wiki ) {
  my $wc = new HTML::WikiConverter(
    html => $html
  );

  ok( $wc->output eq $wiki, $wiki );
}



