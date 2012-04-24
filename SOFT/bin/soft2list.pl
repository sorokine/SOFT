#!/usr/bin/env perl
#

#
# list the entities in ontologies provided the query
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
my $keep_orphans = 1;    # preserve entities with no relations
my $output = '';         # file name to save the list 
my $dumps = [];          # (debugging) dump the content of SOFT object 

# TODO: options to implement
#   --format
#   --separator 
#   --sort

# process command-line options
GetOptions( 
	'v|verbose+'    => \$v, 
	'only=s@'       => \$only, 
	'exclude=s@'    => \$exclude, 
	'orphans!'      => \$keep_orphans,
	'dump:s'        => \$dumps,
	'man' => \$man ) or pod2usage(2);
pod2usage(-exitstatus => 0, -verbose => 2, -output => \*STDERR ) if $man;
#print $v, "\n";

$output = '-' unless $output;

my $softh = SOFT->new( { 'verbose' => $v } );

# read input file
if (@ARGV > 0) {
	foreach my $f (@ARGV) {
		$softh->parse_soft( $f );
	}
} else {
	$softh->parse_soft( '-' );
}
print STDERR "Found in input files: ".$softh->counts()."\n" if $v > 1;

# process entities in only option
$softh->only( &expand( @$only ) ) if (@$only );

# process entities in exclude option
$softh->exclude( &expand( @$exclude ) ) if (@$exclude );

$softh->kill_orphans() unless $keep_orphans;

$softh->dump('-', &expand($dumps)) if $dumps;

$softh->list($output) if $dumps;

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

soft2list - list the entities in ontologies provided the query

=head1 SYNOPSIS

soft2list [options] [ontology.soft [ontology2.soft [...]] [>file.list] 


=head1 OPTIONS

=over 8

=item B<--help,-h>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose,-v+>

increase verbosity

=item B<--output> <file.list>

specify output file name, '-' prints to stdout (default: stdout)

=item B<--exclude> <exclusion list,@file>

Exclude from the output entities listed.  Entities should be separated by comma in the form: I<cat:category,rel:rel1,....>  (can be a I<list>)

=item B<--only> <inclusion list>

Include in the input ONLY entities listed.  Same syntax as in B<--exclude> option.

=item B<--dump> <[all|[ent[ities], rel[ations], sty[les]]] 

dump specified content on the stdin, options are: (can be a I<list>)

=head2 Conventions

=item B<<list>>

list items should be separated with commas, items
starting with @ will be interpreted as names of
files which contain elements on each lines (files 
can be nested)

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and convert them into graphviz gv format.

=cut

