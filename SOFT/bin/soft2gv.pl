#!/usr/bin/env perl
#

#
# SOFT to grpahviz GV file converter, 3rd generation
#

use strict;
use Carp;

use FileHandle;
use Getopt::Long qw(:config no_ignore_case bundling auto_help auto_version);
use Pod::Usage;
use Data::Dumper;

use SOFT;

# make a copy of the command line for the history
my @cmd = (@ARGV);

# options variables
my $v = 0;               # verbosity
my $man = 0; 
my $only = [];           # list of entities to include
my $exclude = [];        # list of entities to exclude
my $sectotl = 1;         # output section outlines
my $sectcol = undef;     # colorize categories by section
my $keep_orphans = 1;    # preserve entities with no relations
my $gvopts = '';         # GV language options for the diagram
my $output = '';         # file name to save the GV diagram 
my $legend = undef;      # file name to save legend (also in GV language)
my $legend_content = ''; # which content to include into legend
my $legend_gvopts = '';  # gv language options for legends
my $styles = [];         # list of style files
my $tuples = [];         # list of files with tuples
my $link_columns = [];   # list of columns to link tuple files with entities
my $tuple_header = 1;    # a flag if tuple file has column name on the first line
my $dumps = [];          # (debugging) dump the content of SOFT object 

# process command-line options
GetOptions( 
	'v|verbose+'    => \$v, 
	'only=s@'       => \$only, 
	'exclude=s@'    => \$exclude, 
	'sect-outline!' => \$sectotl, 
	'sect-color:s'  => \$sectcol,
	'orphans!'      => \$keep_orphans,
	'gvopts=s'      => \$gvopts,
	'o|output=s'    => \$output,
	'legend:s'	=> \$legend,
	'legend-content=s' => \$legend_content,
	'legend-opts=s' => \$legend_gvopts,
	'styles=s@'     => \$styles,
	'tuples=s@'     => \$tuples,
	'columns=s@'    => \$link_columns,
	'tuple-header!' => \$tuple_header, 
	'dump:s'        => \$dumps,
	'man' => \$man ) or pod2usage(2);
pod2usage(-exitstatus => 0, -verbose => 2, -output => \*STDERR ) if $man;
#print $v, "\n";

$output = '-' unless $output;

# check consistency of the options
die "--columns require --tuples files to be specified\n" if $link_columns && !$tuples;

# autoset implied and/or default options
$gvopts = "rankdir=BT" unless $gvopts;

$sectcol = 1 if defined $legend;
if (defined $sectcol) { 
	$sectcol = 'rainbow' unless $sectcol;
	$sectcol =~ m/^(rainbow|random|no(ne)?)$/ || die "Invalid value ($sectcol) for sect-color option.  Try $0 --help.\n";
	$sectcol = undef if $sectcol =~ m/^no(ne)?$/o;
}

if ($v > 2) {
	# print option summary
	print STDERR " -- Run Options --\n";
	print STDERR "\tverbosity=$v\n";
	print STDERR "\tonly=".join(',', @$only)."\n" if $only && @$only;
	print STDERR "\texclude=".join(',',@$exclude)."\n" if $exclude && @$exclude;
    print STDERR "\tsect-outline=$sectotl\n" if $sectotl;
    print STDERR "\tsect-color=$sectcol\n" if $sectcol;
    print STDERR "\torphans=keep_orphans\n" if $keep_orphans;
    print STDERR "\tgvopts=$gvopts\n";
    print STDERR "\toutput=$output\n";
    print STDERR "\tlegend=$legend\n" if defined $legend;
    print STDERR "\tlegend-cont=$legend_content\n" if defined $legend;
    print STDERR "\tlegend-opts=$legend_gvopts\n" if defined $legend;
	print STDERR "\tstyles=".join(',',@$styles)."\n" if $styles && @$styles;
	print STDERR " -----------------\n";
}

my $softh = SOFT->new( { 'verbose' => $v, 'header' => $tuple_header } );

# read input file
if (@ARGV > 0) {
	foreach my $f (@ARGV) {
		$softh->parse_soft( $f );
	}
} else {
	$softh->parse_soft( '-' );
}
print STDERR "Found in input files: ".$softh->counts()."\n" if $v > 1;

# load tuples
if (@$tuples) {
	my @tups = &expand(@$tuples);
	my @cols = &expand(@$link_columns);
	for my $i (0..$#tups) {
		my $lcol=0; 
		my $ltype='cat';
		if ($i<=$#cols) {
			$cols[$i] =~ m/^(\w+):(cat|inst)/o ||
				die "Unable to parse linked column option: ".$cols[$i];
			$lcol  = $1;
			$ltype = $2;
		}
		$softh->load_tuples( $tups[$i], $lcol, $ltype, { 'header' => $tuple_header } ); 
	}
}

# load styles
if (@$styles) {
	foreach my $f (&expand(@$styles)) {
		$softh->parse_styles($f); 
	}
}

# process entities in only option
$softh->only( &expand( @$only ) ) if (@$only );

# process entities in exclude option
$softh->exclude( &expand( @$exclude ) ) if (@$exclude );

$softh->kill_orphans() unless $keep_orphans;

$softh->colorize_by_section( $sectcol ) if $sectcol;

$softh->dump('-', &expand($dumps)) if $dumps;

$softh->build_style_indices();

# output gv file
my $write_opts = { 
	'sectotl' => $sectotl, 
	'sect-color' => $sectcol , 
	'gvopts' => $gvopts,
	'comments' => "Command line:\n$0 ".join(' ', @cmd) 
};
$softh->write_gv( $output, $write_opts );
print STDERR "Written to GV file: ".$softh->counts()."\n" if $v > 1;

# output legend
if (defined $legend) {
	my $legend_opts = { 'content' => $legend_content, 'gvopts' => $legend_gvopts };
	my $lfname = 'stdin-legend.gv';
	if ($legend) { $lfname = $legend }
	elsif ($output && $output ne "-") {
		$lfname = $output;
		$lfname =~ s/^([^.]+)(\w*)/$1-legend$2/;
	}
	$softh->write_legend( $lfname, $legend_opts );
}

exit(0);

sub expand {
	my @list = ();
	foreach (@_) {
		next unless $_;
		chomp;
		foreach (split ',') {
			if (m/^@(.+)/) {
				my $lh = new FileHandle( "<$1" ) || confess "Unable to open file '$1' for reading ($!)\n";
				push @list, map { &expand($_) } <$lh>;
				$lh->close();
			} else {
				push @list, $_;
			}
		}
	}
	return @list;
}

__END__

=head1 NAME

soft2gv - Converts SOFT (Simple Ontology FormaT) into GV format for graphviz

=head1 SYNOPSIS

soft2gv [options] [ontology.soft [ontology2.soft [...]] [>diagram.gv] 


=head1 OPTIONS

=over 8

=item B<--help,-h>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose,-v+>

increase verbosity

=item B<--output> <file.gv>

specify output file name, '-' prints to stdout (default: stdout)

=item B<--exclude> <exclusion list,@file>

Exclude from the output entities listed.  Entities should be separated by comma in the form: I<cat:category,rel:rel1,....>  (can be a I<list>)

=item B<--only> <inclusion list>

Include in the input ONLY entities listed.  Same syntax as in B<--exclude> option.

=item B<--[no]sect-outline>

show boxes around sections on the diagram (default: yes)

=item B<--sect-color> <[=no,none,rainbow,random]>

colorize categories by section, overwrites style files (default: rainbow)

=item B<--[no]orphans>

keep entities with no relations in ontology (default: keep orphans)

=item B<--gvopts> <'rankdir=LR;dpi=96'>

options for the output graph, see GV language manual for details 
(default: rankdir=BT)

=item B<--legend> <[=file.gv]>

save legend in the file (default:<input>-legend.gv, implies --sect-color)

=item B<--legend-content> <sect,rel>

content to include in legend (sections, relations)

=item B<--legend-opts> <'rankdir=LR;dpi=96'>

options for the legend, see GV language manual for details (default: none)

=item B<--styles> <styles.gvsty>

style files to use (can be a I<list>)

=item B<--tuples> <tuples.csv>

tuples to load (can be a I<list>)

=item B<--[no]tuple-header>

tuple file has column name on the first line (default: yes)

=item B<--columns> <name[:cat|inst]>

column name or number to link tuples with enities (defaults to
the 1st column and linking with cats, can be a I<list>)

=item B<--dump> <[all|[ent[ities], rel[ations], sty[les]]] 

dump specified content on the stdin, options are: (can be a I<list>)

=back

=head2 Conventions

=over 4

=item B<<list>>

list items should be separated with commas, items
starting with @ will be interpreted as names of
files which contain elements on each lines (files 
can be nested)

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and convert them into graphviz gv format.

=cut

