package SOFT;

use warnings;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(

);

=head1 NAME

SOFT - Perl module for processing files in Simple Ontology FormaT

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';

use FileHandle;
use File::Basename;
use Carp;
use Data::Dumper;
use Text::Wrap;
use HTML::Entities;

use Convert::Color;
use Convert::Color::HSV;
use Text::CSV;
use Tie::RegexpHash;

# argument is a reference to the hash of option
sub new {
  	my $package = shift;
  
  	my $self = {};
  	
  	# store options
  	$self->{'opts'} = shift || {};
  	$self->{'opts'}->{'verbose'} = 1 unless exists $self->{'opts'}->{'verbose'};
  	
	# create class variables
	# each rel, ent, section hash has an entry 'src' for an array of source files and 'src_line' for an array of line numbers 
  	$self->{'rel'} = []; 	# list of relations
  	   					# each relation is a hash with the following keys:
  						#  id   - relation id
  						#  type - always 'rel'
  						#  from - entity id for from entity
  						#  to   - to entity id for to entity
  						#  style - style object (optional)
  	$self->{'ent'} = {};  # list of entities with their properties as subhashes, entity id is the key for this hash
  						# each entity is a hash with the following keys:
  						#  id    - entity id
  						#  type  - entity type (cat|inst)
  						#  count - entity count
  						#  section - home section
  						#  style - style object (optional)
  	$self->{'sections'} = {}; # list of sections
  						# each entity is a hash with the following keys:
  						#  id    - sections id (full section name delimited with | for each section level)
						#  count - how many time the section has been parsed out from the file
						#  type  - always 'sec'
						#  depth - section depth
						#  members - a hash which keys are entity ids that belong to the section
  	$self->{'includes'} = []; # stack of included soft files
 
 	### setting styles
 	 
	# styles entry in the SOFT object contains indices on style objects
	$self->{'styles'} = {
		'by_id' => {},  # index by style id (all style must be indexed here)
		'count' => 0    # total count of existing styles
	}; 
	# other style indexes has to be created by calling build_style_indices method after loading all style
	# style indices are stored in attributes named like cat_regex for assigning to categories by regex, cat_sect, inst_regex, etc.

 	# each style object is a hash with the following entries:
    #   id => ''   style id, in the form like cat:id
    #   ptrn => ''  matching pattern
    #   seq => ''  sequence number in which styles has been loaded (used for prioritizing)
    #   attrs => {} a hash of style attributes
    #   src => ''  source of the style (typically file name from which style has been loaded)
    #   src_line => '' line in the source file
    #   parent => '' parent style id from which current style has been extended
	my %style = ();

	# default style for relations
	%style = (
		'id' => 'rel:',
		'seq' => 0,
		'attrs' => { 
			'style' => 'dashed',
			'label' => '@ID@' 
		},
		'src' => __FILE__,
		'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	
	# default style for subcategory relation	
	%style = (
		'id' => 'rel:subcat',
		'seq' => 1,
		'attrs' => { 
			'style' => 'solid', 
			'arrowhead' => 'empty' 
		},
		'src' => __FILE__,
		'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };

	# default style for instantiation relation	
	%style = (
		'id' => 'rel:inst',
		'seq' => 2,
		'attrs' => { 
	    	'style' => 'solid',
	    	'penwidth' => 2.0,
	    	'weight' => 5.0,
	    	'arrowhead' => 'dot'
	    },
		'src' => __FILE__,
		'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };

	# default style for categories	
	%style = (
		'id' => 'cat:',
		'seq' => 3,
		'attrs' => {
			'shape' => 'box',
			'label' => '@ID_STRING@',
	    	'weight' => 5.0,
			'~shape' => 'record',
			'~label' => '{@ID_STRING@}|{%@PNAME@=@PVAL@%|%}'
		}, 
		'src' => __FILE__,
		'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };

	# default style for instances	
	%style = (
		'id' => 'inst:',
		'seq' => 4,
		'attrs'  => {
			'shape' => 'box3d',
	    	'penwidth' => 2.0,
			'label' => '@ID_STRING@',
			'~style' => 'rounded',
			'~shape' => 'record',
			'~label' => '{@ID_STRING@}|{%@PNAME@=@PVAL@%|%}'
		}, 
		'src' => __FILE__,
		'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	
	# default styles for sections
	%style = (
		'id' => 'sec:', 'seq' => 5,, 'depth' => 0,
		'attrs'  => { 'label' => '@SECTION@'	}, 
		'src' => __FILE__, 'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	%style = (
		'id' => 'sec:1:', 'seq' => 6, 'depth' => 1,
		'attrs'  => { 'label' => '@SECTION@', 'color' => 'gray10', 'fontcolor' => 'gray10', 'labelloc' => 'b' }, 
		'src' => __FILE__, 'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	%style = (
		'id' => 'sec:2:', 'seq' => 7, 'depth' => 2,
		'attrs'  => { 'label' => '@SECTION@', 'color' => 'gray20', 'fontcolor' => 'gray20', 'labelloc' => 'b'  }, 
		'src' => __FILE__, 'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	%style = (
		'id' => 'sec:3:', 'seq' => 8, 'depth' => 3,
		'attrs'  => { 'label' => '@SECTION@', 'color' => '#8547FF', 'fontcolor' => '#8547FF', 'labelloc' => 'b'  }, 
		'src' => __FILE__, 'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	%style = (
		'id' => 'sec:4:', 'seq' => 9, 'depth' => 4,
		'attrs'  => { 'label' => '@SECTION@', 'color' => 'gray40', 'fontcolor' => 'gray40', 'labelloc' => 'b'  }, 
		'src' => __FILE__, 'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	%style = (
		'id' => 'sec:5:', 'seq' => 10, 'depth' => 5,
		'attrs'  => { 'label' => '@SECTION@', 'color' => 'darkgreen', 'fontcolor' => 'darkgreen', 'labelloc' => 'b'  }, 
		'src' => __FILE__, 'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	%style = (
		'id' => 'sec:6:', 'seq' => 11, 'depth' => 6,
		'attrs'  => { 'label' => '@SECTION@', 'color' => 'red', 'fontcolor' => 'red', 'labelloc' => 'b'  }, 
		'src' => __FILE__, 'src_line' => __LINE__
		);
	$self->{'styles'}->{'by_id'}->{$style{'id'}} = { %style };
	
	$self->{'styles'}->{'count'} = scalar keys %{$self->{'styles'}->{'by_id'}};  # update style count

  	return bless($self, $package);
}

### methods for access to ontology entries

# retrieve the entity from ontology
#   expects a string representing entity names, e.g., 'cat:entity'
#   returns a reference to hash array directly in the datastore or 
#     undef if entity  not found (no error is raised)
sub get {
	my $self = shift;
	my $ent = shift;

	return $self->{'ent'}->{$ent};
}

# lists all entities in the ontology
#   TODO: add the condition to select entities (use same rules as in assigning styles)
#   a list of strings representing entities is returned (in the form type:entity)
sub all {
	my $self = shift;
	
	return keys %{$self->{'ent'}};
}

# adds a new entity to ontology
#  arguments
#    entity name in the for type:name, e.g.: cat:entity, required
#    section (may be empty)
#    source file (may be empty)
#    line in the source file (must be empty if source file is empty)
#  returns
#    a reference to the hash array containing the entity
#  fails
#    if entity already exists
#    if entity name is not parseable
#    if section has not been created before
sub add {
	my ($self, $ent, $section, $src_file, $src_line) = (@_);
	
	croak "Attempt to create an existing entity ($ent)" if $self->get($ent);

	$ent =~ m/^([^:]+):(\S+)$/o || 
		croak "Unable to parse entity name: $ent (should be in form 'type:name') [$src_file:$src_line]";
	my ($type,$id) = ($1, $2);
		
	$type =~ m/^(cat|inst)$/ || 
		croak "Unrecognized entity type: $type (should be cat or inst) [$src_file:$src_line]";
	
	my %e = ( 'id' => $id, 'type' => $type );
	
	if ($section) {
		confess "Section $section was not found in ontology while creating entity $ent"
			unless exists $self->{'sections'}->{$section};
		$e{'section'} = $section;
	    $self->{'sections'}->{$section}->{'members'}->{$ent} = 1;
	}
	if ($src_file) {
		$e{'src'} = [ $src_file ];
		$e{'src_line'} = [ $src_line ] || 
			croak "No source line provided for entity $ent";
	} else {
		$e{'src'} = [];
		$e{'src_line'} = []; 
		carp "Source file not specified for '$ent'" if $self->{'opts'}->{'verbose'};
	}
	
	return $self->{'ent'}->{$ent} = \%e;
}

# updates an existing entity in ontology (fails if entity does not exists)
#  arguments
#    entity name in the for type:name, e.g.: cat:entity, required
#    section (may be empty)
#    source file (may be empty)
#    line in the source file (must be empty if source file is empty)
#  returns
#    a reference to the hash array containing the entity
#  fails
#    if entity does not exist
#    if entity name is not parseable
#    if section has not been created before
sub update {
	my ($self, $ent, $section, $src_file, $src_line) = (@_);
	
	my $e = $self->get($ent) ||
		croak "SOFT: entity to be updated was not found ($ent)";
	
	if ($section) {
		confess "Section $section was not found in ontology while creating entity $ent"
			unless exists $self->{'sections'}->{$section};

		if ($e->{'section'} && $e->{'section'} ne $section) {
			# if section is different from already specified update other section data and complain if necessary
	   		delete $self->{'sections'}->{$section}->{'members'}->{$ent};
	   		carp "SOFT: Section name update for $ent (".$e->{'section'}." = $section)" 
	   			if $self->{'opts'}->{'verbose'};
		}
		$e->{'section'} = $section;
	    $self->{'sections'}->{$section}->{'members'}->{$ent} = 1;
	}
	
	if ($src_file) {
		push @{$e->{'src'}},      $src_file;
		push @{$e->{'src_line'}}, $src_line ;
	}
	
	return $e;
}

# updates and if it exists, adds a new entity if not
# arguments are passed directly to add or update
sub add_or_update {
	my $self = shift;
	my $ent = $_[0];
	
	return $self->get($ent) ? $self->update(@_) : $self->add(@_);
}

# deletes an entity from ontology
# arguments:
#   entity name in the form cat:name
# returns
#   hash array of the deleted entity or undef on failure
sub del {
	my $self = shift;
	my $ent  = shift;
	
	my $e = $self->get($ent) || return undef;
	
	# cleanup relations
	$self->{'rel'} = [ grep { $_->{'to'} ne $ent && $_->{'from'} ne $ent } @{$self->{'rel'}} ];

	# remove references from sections
	foreach my $sec (keys %{$self->{'sections'}}) {
		delete $self->{'sections'}->{$sec}->{'members'}->{$ent};
	}
	
	# remove the entity
	delete $self->{'ent'}->{$ent};

	return $e;
}

# retrieve a property value from an entity
# arguments:
#   entity name in the form cat:name
#   property name
# return
#   a string connecting the property value or undef if no such property or 
#   entity has no properties
# the method will croak if no entity does not exist
sub get_prop {
	my ($self, $ent, $prop) = (@_);
	
	my $e = $self->get($ent) ||
		croak "Retrieving a property ($prop) from a non-existent entity ($ent) attempted";
	
	return undef unless exists $e->{'properties'};
	return $e->{'properties'}->{$prop} if exists $e->{'properties'}->{$prop};
	return undef;
}

# retrieve an entity id
# arguments:
#   entity name in the form cat:name
# return
#   a string connecting an entity id or undef if entity does not exist
sub get_id {
	my ($self, $ent) = (@_);
	
	my $e = $self->get($ent) || return undef;
	return $e->{'id'};
}

# TODO: del_all delete all entities satisfying certain selection criteria

### methods for loading ontology files

sub parse_soft {
	my $self = shift;
	my $fname = shift || croak "File name must be provided";
	my $csection_ref = shift || []; # reference to an array of section name under which to include parsed SOFT file
	
  	# check for cyclical includes
  	foreach (@{$self->{includes}}) {
  		croak "Cyclical include of $fname, include/comprise stack: ".join("<-", @{$self->{includes}}) if m/$fname/;
  	}
  	push @{$self->{includes}}, $fname;
	  	
	# open input file for reading, check the directory name
	my $fh = undef;
	my $basedir = '';
	if ($fname eq '-') {
		$fh = \*STDIN;
	} else {
  		$fh = new FileHandle "<$fname";
  		die "Unable to open '$fname'" unless $fh; # TODO print include stack here
		$basedir = dirname($fname);
		# fix the basedir name to handle ending / properly
		$basedir = '' if $basedir eq '.';
		$basedir .= '/' if $basedir && $basedir !~ m|/$|o;
	}

	my $c = -1;           # line counter
	my @ditto = ();        # array of parsed tokens (up to 3 tokens: ent1 -rel-> ent2) for ditto operation
	my $prev_line = undef; # previous line for processing line continuations
	
	my $fsec;  # full section name
	my @csection = @$csection_ref;
	my $addepth = @csection; # additional section depth inherited from upper file

	# parse
	while (<$fh>) {
	  chomp;
	  $c++;
	
	  # get rid of leading and trailing space
	  s/^\s*//o;
	  s/\s*$//o;

	  # if there is previous line then prepend it to current line
	  $_ = "$prev_line $_" if $prev_line; 

	  # if the line ends up in \ the assign it to continuations
	  if (s/\\$//o) {
	  	$prev_line = $_;
	  	next;
	  }
	  $prev_line = undef;
	
	  # get rid of comments 
	  s/#.*$//o;
	  
	  # get rid of empty lines
	  next if /^\s*$/o;
	
	  # process \include and \comprise
	  if (m/^\\(include|comprise|styles|tuples)\s+([\S]+)(?:\s+(.*))?/o) {
	  	my $op = $1;
	  	my $incname = $2;
	  	my $opts = $3;
	  	
	  	if ($op eq 'include') {
	  		$self->parse_soft($basedir.$incname);
	  		@csection = (undef);
	  	} elsif ($op eq 'comprise') { 
	  		$self->parse_soft($basedir.$incname, \@csection);
	  	} elsif ($op eq 'styles') {
	  		$self->parse_styles($basedir.$incname);
	  	} elsif ($op eq 'tuples') {
			my $lcol=0; 
			my $ltype='cat';
			if ($opts) {
				$opts =~ m/^(\w+):(cat|inst)/o ||
					die "Unable to parse \\tuples directive on line $c in file $fname";
				$lcol  = $1;
				$ltype = $2;
			}
	  		$self->load_tuples( $basedir.$incname, $lcol, $ltype );
	  	} else {
	  		croak "Directive $_ not recognized on line $c in file $fname";
	  	}
	  	
	  	@ditto = ();
	  	next;
	  }
	  
	  # Process Section
	  if (m/^(\[+)([^\[\]]+)/o) {
	    my $d = length($1) - 1 + $addepth;
	    splice @csection, $d if @csection > $d;
	    $csection[$d] = $2;
	
	    # record full section name into section list
	    $fsec = join '|', @csection;
	    $self->{'sections'}->{$fsec} = { 'type'=>'sec', 'id'=>$fsec, 'depth'=>_sec_lev($fsec), 'src'=>[], 'src_line'=>[], 'count'=>0, 'members'=>{} } 
	    	unless exists $self->{'sections'}->{$fsec};
		
  		push @{ $self->{'sections'}->{$fsec}->{'src'} }, $fname;
		push @{ $self->{'sections'}->{$fsec}->{'src_line'} }, $c;
	    $self->{'sections'}->{$fsec}->{'count'}++;
	
		@ditto = (); # no ditto for sections
	    next;
	  }
	
	  # process ditto
	  if (m/~/o) {
	  	croak "Ditto character found but no line to copy from" unless @ditto;
	  	my (@tokens) = (m/^([^~\s]+)\s*([^~\s]*)\s*~/o); 
	  	croak "Ditto character found but not able to make sense of it, line #$c in $fname" unless @tokens;
	  	pop @tokens unless $tokens[$#tokens]; # remove last token if it is empty
	  	$_ = join ' ', (@tokens, @ditto[$#tokens+1..$#ditto]);
	  }
	  @ditto = split /\s+/;
	
	  # cat:texture -subcat-> cat:property
	  my ( $nosec1, $ent1, $dir_rev, $rel, $dir_fwd, $nosec2, $ent2 ) =
	    (m/^(\*?)(\S+)\s+(<?)-(\S+)-(>?)\s+(\*?)(\S+)/o);
	  defined $ent1 || croak "Failed to parse line #$c in file $fname ($_)";
	
	  ( $dir_rev || $dir_fwd ) || croak "Undirected relations are not allowed, line #$c ($_)\n";
	
	  $self->add_or_update( $ent1, $nosec1 ? undef : $fsec, $fname, $c);
	  $self->add_or_update( $ent2, $nosec2 ? undef : $fsec, $fname, $c);
	
	  # store relation
	  my $rel_object =  $dir_fwd ? 
	    { 
	     'from' => $ent1,
	     'type' => 'rel',
	     'id'   => $rel,
	     'to'   => $ent2
	    } : { 
	     'to'   => $ent1,
	     'type' => 'rel',
	     'id'   => $rel,
	     'from' => $ent2
	    };
	  $rel_object->{'src'} = [$fname];
	  $rel_object->{'src_line'} = [$c];
	  push @{$self->{rel}}, $rel_object;
	   	
	}

	$fh->close() unless $fname eq '-';
  	pop @{$self->{includes}};
  	carp "Continuation line not found in $fname line #$c" if $prev_line; # complain if the last line ends with \
}

# parse a style file
# this method only loads styles into {'styles'}->{'by_id'} hash, run build_style_indices before using write_gv
sub parse_styles {
	my $self = shift;
	my $fname = shift || croak "File name must be provided";
		
	my $fh = new FileHandle "<$fname";
  	die "Unable to open style file '$fname'" unless $fh;

	# extract base directory name if any
	my $basedir = dirname($fname);
	# fix the basedir name to handle ending / properly
	$basedir = '' if $basedir eq '.';
	$basedir .= '/' if $basedir && $basedir !~ m|/$|o;
	
	my $c = -1;            # line counter
	my $prev_line = undef; # previous line for processing line continuations
	my $instyle = undef;   # flag showing if parser is the style definition section

	# parsing variables for style specification
	my $style_id = undef;  # style identifier
	my $ptrn_type = undef; # entity type to which pattern applies, eg. rel:, cat:, ...
	my $ptrn = undef;      # pattern to match style with applicable entities
	my $parent = undef;    # entry from which style derives
	my $sec_depth = 0;	   # section depth for section styles
  	
    my %style = ();        # hash for style object with the following members:

	# parse
	while (<$fh>) {
	  chomp;
	  $c++;
	
	  # get rid of leading and trailing space
	  s/^\s*//o;
	  s/\s*$//o;

	  # if there is previous line then prepend it to current line
	  $_ = "$prev_line $_" if $prev_line; 

	  # if the line ends up in \ the assign it to continuations
	  if (s/\\$//o) {
	  	$prev_line = $_;
	  	next;
	  }
	  $prev_line = undef;
	
	  # get rid of comments 
	  s/^#.*$//o;
	  
	  # get rid of empty lines
	  next if /^\s*$/o;
	
	  unless ($instyle) {
	  	# \style[=(rel|cat|inst|sec):ID] (rel|cat|inst|sec):pattern [extends (rel|cat|inst|sec):<other_style_ID>]
	  	
	  	my $idre = qr/(?:rel|cat|inst|sec):[^\s]*/o; # regex for entry ID
	  	if (m/^\\style(?:=($idre))?\s+($idre)(?:\s+extends\s+($idre))?/o) {
	  		$style_id = $1 || $2; # style id defaults to pattern if not specified, prepended with type, e.g. cat:id
	  		( $ptrn_type, $ptrn ) = split ':', $2, 2;
			$parent = $3;

			# extract section depth if present
		    if ($ptrn_type eq 'sec') {
		    	$ptrn =~ m/^(?:(\d+):)(.+)$/o;
		    	$sec_depth = $1 || 0;
		    	$ptrn = $2;
		    }
		    
		    # insert basedir name into assignment-by file name pattern
		    $ptrn =~ s/^@/\@$basedir/ if $ptrn && $basedir;
			
			%style = ( 
				'id'    => $style_id, 
				'seq'   => $self->{'styles'}->{'count'}++, 
				'type'  => $ptrn_type,
				'ptrn'  => $ptrn || '',
				'attrs' => {},
				'src'   => $fname,
				'src_line' => $c 
				);
			$style{'depth'} = $sec_depth if $ptrn_type eq 'sec';
			$style{'parent'} = $parent if $parent;
			if ($parent) {
				die "Superstyle not found for line $c in $fname ($_)" unless exists $self->{'styles'}->{'by_id'}->{$parent};
				$style{'attrs'} = { %{$self->{'styles'}->{'by_id'}->{$parent}->{'attrs'}} }; 
			}
			$instyle = 1;
	  	} else { # not inside style defintion
	  		die "Failed to parse style header line $c in file $fname ($_)";
	  	}
	  } else {
	  	if (m/^\\style\s*$/o) { # end of style defintion found
	  		# all styles has to be added to by_id index
	  		$self->{'styles'}->{'by_id'}->{$style_id} = {%style}; 
	  		
	  		# reset parsing
	  		%style = ();
	  		$instyle = undef;
	  	} elsif (m/([^=]+)=(.*)/o) { # parse style attributes
	  		$style{'attrs'}->{$1} = $2;
	  	} else { # hui znaet chto
	  		croak "Failed to parse style attribute line $c in file $fname ($_)";
	  	}
	  }
	}
	  	
	die "Unfinished style defintion at the end of file $fname" if $instyle;
  	$fh->close();
  	
}

# static method that creates a regexhash
sub _create_regexhash {
	my %by_regex;
	tie %by_regex, 'Tie::RegexpHash';
	return \%by_regex; 
}

# builds style indices
sub build_style_indices {
	my $self = shift;

  	# fill in the appropriate indexes in the styles tables
  	# styles has to be added to regex hash in the order opposite to which it has been loaded 
  	foreach my $s (sort { $b->{'seq'} <=> $a->{'seq'} } values %{$self->{'styles'}->{'by_id'}}) {
  		#print "Style loaded: ".$s->{'id'}." #".$s->{'seq'}." from ".$s->{'src'}." line ".$s->{'src_line'}."\n";
  		
  		$s->{'ptrn'} ||= ''; # some of the styles may have patter undefined, in that case substitute is with

		# several patterns can be concatenated with a comma, each of the concatenated patterns will be added to corresponding index
   		foreach (reverse split ',', $s->{'ptrn'}) {

  			if (m/^\[(.+)\]$/o) { # assignment by section

				# create an index hash if doe not exist	  		
				my $ind_name = $s->{'type'}.'_'.'sect';

				$self->{'styles'}->{$ind_name} = _create_regexhash ($self, $ind_name) 
					unless exists $self->{'styles'}->{$ind_name};
	  			
	  			$self->{'styles'}->{$ind_name}->{ qr/(?:^|\|)$1(?:$|\|)/ } = $s;
  				
  			} elsif (m/^@(\S+)/o) { # assignment by source
 				# create an index hash if doe not exist	  		
				my $ind_name = $s->{'type'}.'_src';
  				
				$self->{'styles'}->{$ind_name} = {} 
					unless exists $self->{'styles'}->{$ind_name};
					
				# check if the source files exists and is readable
				-f $1 || croak "Unable to find file '$1' specified in style ".$s->{'id'}." loaded from ".$s->{'src'}." line ".$s->{'src_line'};
				
				$self->{'styles'}->{$ind_name}->{$1} = $s;
				
  			} elsif (m/<?-\w+->?/o) { # assignment by relation
  				
 				# create an index hash if doe not exist	  		
				my $ind_name = $s->{'type'}.'_rel';
  				
				$self->{'styles'}->{$ind_name} = {} 
					unless exists $self->{'styles'}->{$ind_name};
					
				$self->{'styles'}->{$ind_name}->{$_} = $s;
				
  			} elsif ( ! m/^\/.+\/$/o )  { # everything else that is not regex
  				# convert glob symbols to regex 
	  			s/\*/.*/og;
  				s/\?/.?/og;
  				# convert it into a trivial "match exact word" regex
  				$_ = '/^'.$_.'$/';
  			} 
  			
			if (m/^\/.+\/$/o) { # then this is regex
			
				# create an index hash if doe not exist	  		
				my $ind_name = $s->{'type'}.'_regex';
				$self->{'styles'}->{$ind_name} = _create_regexhash ($self, $ind_name) 
					unless exists $self->{'styles'}->{$ind_name};
	  			
		  		my $qr = eval "qr$_";
		  		$@ && croak "Failed to parse a regex in $_ ($@)";
	  			$self->{'styles'}->{$ind_name}->{ $qr } = $s;
	  			
			}
	  	}
  	}
}

# load tuples
# arguments are
#   file name to load from
#   a column (name or number from 0) to link from 
#   type on entities to link to (cat or inst)
#   hash with options
#     - header=1 the tuple file contains a header
sub load_tuples {
	my ($self, $fname, $lcol, $ltype, $opts) = (@_);
	confess "No tuple file name has been provided" unless $fname;
	confess "Linking column and/or linking entity type has not been defined for tuple file '$fname'"
	  unless defined $lcol && $ltype;
	$opts = $self->{'opts'} unless $opts;
	
	$opts = $self->{'opts'} unless $opts;
	$opts->{'header'} = 1 unless exists $opts->{'header'};
	
	my $fh = new FileHandle "<$fname";
  	die "Unable to open tuple file '$fname'" unless $fh;
	binmode $fh, ':encoding(UTF-8)';

  	my $csv = Text::CSV->new();
	my $c = -1;            # line counter
	my $prev_line = undef; # previous line for processing line continuations
	my @prop_names = (); # a list of property names
  	
	# parse
	while (<$fh>) {
	  chomp;
	  $c++;
	
	  # get rid of leading and trailing space
	  s/^\s*//o;
	  s/\s*$//o;

	  # if there is previous line then prepend it to current line
	  $_ = "$prev_line $_" if $prev_line; 

	  # if the line ends up in \ the assign it to continuations
	  if (s/\\$//o) {
	  	$prev_line = $_;
	  	next;
	  }
	  $prev_line = undef;
	
	  # get rid of comments 
	  s/^#.*$//o;
	  
	  # get rid of empty lines
	  next if /^\s*$/o;
	  
	  my @columns;
      if ($csv->parse($_)) {
        @columns = $csv->fields();
      } else {
        my $err = $csv->error_input;
        print "Failed to parse line $c in the CSV file $fname: $err";
      }

	  # setting property names, reading column name from the file
	  unless (@prop_names) {
	  	if ($opts->{'header'}) { # first line contains column names
	  		@prop_names = @columns;
	  		if ($lcol !~ /^\d+$/o) { # if linking column is not a number then find it in the list of column names
	  			my $icol = 0;
	  			foreach (@prop_names) {
	  				last if m/$lcol/;
	  				$icol++;
	  			}
	  			croak "Unable to find link column name ($lcol) in the header of the csv file $fname" if $icol > $#prop_names;
	  			$lcol = $icol; 
	  		} else {
	  			# check that $lcol is within the range
	  			croak "Linking column number ($lcol) is large than the number of columns in the file header ".scalar(@prop_names)
	  				if $lcol - 1 > @prop_names;
	  		}
	  		next;
	  	} else { # no column names in the first line -- simply use numbers
	  		@prop_names = (0..$#columns);
	  		croak "Link column must be a number unless csv file has column names in the first line (current link column $lcol)" unless $lcol =~ /^\d+$/o;
	  	}
	  }

	  print STDERR "WARNING: line $c in $fname has different number of columns than the file header (".scalar(@columns)." found but header had ".scalar(@prop_names)." columns)\n" unless
	  	$#columns == $#prop_names;
	  	
	  croak "Zero-length string in link column on line $c in $fname" unless $columns[$lcol];
	  
	  # creating a new entity or checking the existing one
	  my $e = $self->add_or_update("$ltype:".$columns[$lcol], undef, $fname, $c );

	  # create or increase tuple count
	  if ($e->{'tuple_count'}) {
	  	$e->{'tuple_count'}++;
	  } else {
	  	$e->{'tuple_count'} = 1;
	  }

	  # loading values into properties
	  # TODO: move to property handling functions
	  $e->{'properties'} = {} unless exists $e->{'properties'};
	  foreach my $i (0..$#columns) {
	  	last if $i > $#prop_names; # ignore remaining columns
	  	$e->{'properties'}->{$prop_names[$i]} = $columns[$i];
	  }

	} # end of parsing loop	
	
	$fh->close();
}

# exclude entities from the ontology
# TODO: exclude by pattern like in style assignment
sub exclude {
	my $self = shift;
	foreach (@_) { # expects an array of entities to be exclude in the form cat:category, rel:rel1, ....
		if (m/^rel:(.+)/o) {
			$self->{'rel'} = [ grep { $_->{'id'} ne $1 } @{$self->{'rel'}} ];
		} else {
			# entities
			$self->del($_) ||
				print STDERR "WARNING: exclude entity '$_' was not found in ontology (ignored)\n";
		}
	}
}

# exclude entities from the ontology that are not in the provided list
# TODO: include by pattern like in style assignment
sub only {
	my $self = shift;
	my %ecats = (%{$self->{'ent'}}); # list of categories to exclude
	my $have_cats = 0;
	foreach (@_) { # expects an array of entities to be exclude in the form cat:category, rel:rel1, ....
		if (m/^rel:(.+)/o) {
			$self->{'rel'} = [ grep { $_->{'id'} eq $1 } @{$self->{'rel'}} ];
		} else {
			delete $ecats{$_} if exists $ecats{$_};
			$have_cats = 1;
		}
	}
	$self->exclude(keys %ecats) if $have_cats;
}

# remove entities that do not have any relations
sub kill_orphans {
	my $self = shift;
	
	my @orphans = ();
	ENT: foreach my $k (keys %{$self->{'ent'}}) {
		foreach my $r (@{$self->{'rel'}}) {
			next ENT if ($r->{'to'} eq $k || $r->{'from'} eq $k);
		}
		push @orphans, $k;
	}
	$self->exclude( @orphans );
}

# static method that returns section level number
sub _sec_lev {
	my $s = shift || return 0;
	
	return ($s =~ tr/|/|/) + 1;
}

# assign colors to the entities according the section
sub colorize_by_section {
	my $self = shift;
	my $method = shift || confess "Section coloring method not specified in the function call\n";
		# method can be either 'rainbow' or 'random'
	my $upper = shift || '';   # upper section name, must be empty on the 1st run
	my $hue0 = shift ||   0.0; # interval of hues on which to operate on
	my $hue1 = shift || 360.0;

	# count level as the number of section delimiter '|' in the upper section name 
	my $lev = _sec_lev($upper);
	
	# on the 1st run calculate the number of levels
	unless ($lev) {
		$self->{'sec_legend'} = {} unless exists $self->{'sec_legend'};
		$self->{'_maxlev'} = 0;
		foreach (keys %{$self->{'sections'}}) {
			my $lev2 = _sec_lev($_);
			$self->{'_maxlev'} = $lev2 if $lev2 > $self->{'_maxlev'};
		}
	} 
	
	my @sec_list = sort grep { (_sec_lev($_) == $lev + 1 && m/^$upper/o)} keys %{$self->{'sections'}};
	if (@sec_list) {
		my $hue_inc = ($hue1 - $hue0) / @sec_list;
		for(my $i=0; $i < @sec_list; $i++ ) {

			# create color for current section
			my $hue = $hue0;
			if ( $method eq 'random' ) {
				$hue = rand 360.0; #$hue0 + $i * $hue_inc;
			} elsif ( $method eq 'rainbow' ) {
				$hue = $hue0 + $i * $hue_inc;
			} else {
				confess "Unknown section coloring method '$method'\n";
			}
			my $sat = ($lev+1)/$self->{'_maxlev'} / 2.0;
			my $color = Convert::Color::HSV->new( $hue, $sat, 1.0 );
			#print STDERR $color->as_rgb8->hex." H=$hue S=$sat V=1.0\n";
			$self->{'sec_legend'}->{$sec_list[$i]} = $color->as_rgb8->hex;
			#$self->{'sec_legend'}->{$sec_list[$i]} = "H=$hue S=$sat V=1.0";

			# assign style for each entity in the section
			foreach my $ent (keys %{$self->{'sections'}->{$sec_list[$i]}->{'members'}}) {
				$self->{'ent'}->{$ent}->{'style'} = { 
					'style' => 'filled',
					'fillcolor' => "#".$color->as_rgb8->hex
				} if exists $self->{'ent'}->{$ent};
			}
			# do subsections
			$self->colorize_by_section( $method, $sec_list[$i], $hue0 + $i * $hue_inc, $hue0 + $i * $hue_inc + $hue_inc);
		}	
	}
}

# write graphviz gv file
# options are file name and a hash with options
# the options are:
#  gvopts -- string with GV language options
#  sectotl -- render section outlines (1/0)
#  properties -- show properties on the entity output
#  comments -- a string that will be printed in the beginning on the GV file as a GV language comment
sub write_gv {
	my $self = shift;
	my $fname = shift || croak "File name must be provided";
	my $opts = shift || { 'sectotl' => 1 }; # second argument is hash with options
	
	confess "No styles indices found while attempting to write a gv file" 
		unless exists $self->{'styles'}->{'by_id'};
	
	my $fh = undef;
	if ($fname eq '-') {
		$fh = \*STDOUT;
	} else {
		$fh = new FileHandle ">$fname" || die "Unable to open '$fname' for writing";
	}
	binmode $fh, ':encoding(UTF-8)';

	print $fh "/* This file was auto-generated on ".localtime()."\n   using SOFT.pm library version $VERSION.  ";
	print $fh $opts->{'comments'}."\n" if ($opts->{'comments'});
	print $fh "*/\n";
	
	print $fh "digraph G {\n";
	print $fh "\t".$opts->{'gvopts'}."\n" if exists $opts->{'gvopts'} && $opts->{'gvopts'};

	if (exists $opts->{'sectotl'} && $opts->{'sectotl'}) {
		# output section boxes if requested
		# TODO omit sections with no entities in any subsection 
		print $fh "\t/* subgraphs */";
		my $ck = 0;
		my $pd = -1;
		foreach my $k (sort keys %{$self->{sections}}) {
		  	#print STDERR "$k\n";
			
			my $cd = ($k =~ tr/|//); # current depth
		
		    $k =~ m/([^|]+)$/o;
		    my $label = $1;
		
		    foreach my $l (reverse $cd..$pd) {
		    	print $fh "\t" x $l . "\t}\n";
		  	}
		
			# TODO replace with make_style
		  	print $fh "\n" . "\t" x $cd . "\tsubgraph cluster".$ck++." {\n";
		  	print $fh "\t" x $cd . "\t\t".$self->make_style( $self->{'sections'}->{$k} ).";\n";
		  	print $fh join "", map { "\t" x $cd . "\t\t\"$_\";\n" } keys %{$self->{'sections'}->{$k}->{'members'}} 
		  		if keys %{$self->{'sections'}->{$k}->{'members'}}; 
		
		  	$pd = $cd;
		}
		foreach my $l (reverse 0..$pd) {
			print $fh "\t" x $l . "\t}\n";
		}
		print $fh "\n";
	}
		
	print $fh "\t/* node attributes */\n";
	foreach my $key (sort $self->all()) {
    	print $fh "\t\"$key\" [".$self->make_style( $self->get($key) )."];\n";
	}
	print $fh "\n";
	
	print $fh "\t/* relations with attributes */\n";
	foreach my $r (@{$self->{rel}}) {
		print $fh "\t\"".$r->{'from'}."\" -> \"".$r->{'to'}."\" [".$self->make_style($r)."];\n";
	}
	
	print $fh "}\n";
	
	$fh->close() unless $fname eq '-';
}

# creates a GV style string given an entity or relation 
sub make_style {
	my $self = shift;
	my $entry = shift; # entity, relation, or section object
	
	my $id   = $entry->{'id'};
	my $type = $entry->{'type'};
	confess "An argument to make_style does not have id and/or type property\n".Dumper($entry) 
		unless $id && $type;
	
	# special processing for section:
	# extract section depth
	
	# search for matching style, first try exact match of the entity id 
	my $style_ref = 
		$self->{'styles'}->{'by_id'}->{"$type:$id"} || 
		$self->{'styles'}->{'by_id'}->{"$type:"};
	confess "Internal error: entity type $type:$id was not found in the style array." unless $style_ref;

	# special processing for sections (checking for depth)
	if ($type eq 'sec') {
		my $style_ref2 = $self->{'styles'}->{'by_id'}->{"$type:"._sec_lev($id).':'};
		$style_ref = $style_ref2 if ($style_ref2 && $style_ref->{'seq'} < $style_ref2->{'seq'});
	}

	# second try available search indices for the entity type	
	foreach (qw/regex sect src rel/) { # for each index type
		last if $style_ref->{'seq'} >= $self->{'styles'}->{'count'};
		my $indx = $self->{'styles'}->{ $type.'_'.$_ } || next;

		# should be different for different index types
		my $style_found = undef;
		if (m/regex/o) {
			$style_found = $indx->{$id};
		} elsif (m/sect/o) {
			next unless $entry->{'section'}; # sections may be empty
			$style_found = $indx->{$entry->{'section'}};
		} elsif (m/src/o) {
			$style_found = (                         # get the first style 
				sort { $b->{'seq'} <=> $a->{'seq'} } # sort the styles in reverse of the sequence they were loaded 
					grep {defined}                   # get rid of undefined entries for which styles do not exist
						map { $indx->{$_} } 		 # find each source file in the style index 
							@{ $entry->{'src'} }     # retrieve a list of all source files in which the entry has been found
			)[0];
		} elsif (m/rel/o) {
			$style_found = (                         # get the first style 
				sort { $b->{'seq'} <=> $a->{'seq'} } # sort the styles in reverse of the sequence they were loaded 
					grep {defined}                   # get rid of undefined entries for which styles do not exist
						map { $indx->{$_} } (        # look in the index for styles that have specified relation
							# record relation the same way it may be recorded in the style definiton, 
							# make two entries: first is the relation name and second is the relation with a category on one of the ends 
							(map { ( '<-'.$_->{'id'}.'-', '<-'.$_->{'id'}.'-'.$self->{'ent'}->{$_->{'from'}}->{'type'}.':'.$_->{'from'} ) } 
								grep { $_->{'to'} eq $id } # grep relations that have current entities on the to side
									@{ $self->{'rel'} }),
							(map { ( '-'.$_->{'id'}.'->', '-'.$_->{'id'}.'->'.$self->{'ent'}->{$_->{'to'}}->{'type'}.':'.$_->{'to'} ) }
								grep { $_->{'from'} eq $id }  # grep relations that have current entities on the from side
									@{ $self->{'rel'} })
						)
			)[0];
		} else {
			confess "oops! something really odd happened at ".__FILE__.':'.__LINE__."!!!";
		}
		next unless $style_found;
		next if ($type eq 'sec' && $style_found->{'depth'} && $style_found->{'depth'} != _sec_lev($id));
		
		$style_ref = $style_found if ($style_found->{'seq'} > $style_ref->{'seq'});
	}
	
	my %attrs = %{ $style_ref->{'attrs'} };
	# combine with the entry-specific style overwriting default values
	if (exists $entry->{'style'}) {
		while ( my($k, $v) = each (%{$entry->{'style'}})) {
			$attrs{$k} = $v;
		}
	}
	
	# clean %style of property-specific attributes
	while ( my($k, $v) = each (%attrs) ) {
		if (exists $entry->{'properties'} && $k =~ m/^\~(.+)/o) {
			$attrs{$1} = $v;
		} 
		delete $attrs{$k} if $k =~ m/^~/o;
	}
	
	# assemble GV style string
	my @s = ();
	while (my ($k, $v) = each(%attrs)) { 
		# replace iterator templates
		$v =~ s/%([^%]*)%([^%]*)%/$self->exp_iterator($1, $2, $entry)/ge;
		# replace templates
		$v =~ s/\@([^\@]*)\@/$self->exp_ent($1, $entry)/ge;
		# try to detect HTML formatting for nodes
		if ($v =~ m/\<TABLE/io) {
			push @s, "$k=<$v>";
		} else {
			push @s, "$k=\"$v\"";
		} 
	}
	
	# in GV style separator for sections is different from the one for nodes and lines
	my $sep = ($type eq 'sec') ? "; " : ',';
	my $s = join $sep, @s;

	return $s;
}

# expand iterator template
# will repeat the string for each key=val pair in properties 
sub exp_iterator {
	my ($self, $str, $sep, $entry) = (@_); # var is a template variable, entry is a relation or entity object
	
	return '%' unless $str;
	croak "No properties object for iterator template %$str% in ".$entry->{'id'} unless exists $entry->{'properties'};
	
	my @accum = ();
	while (my ($k, $v) = each(%{$entry->{'properties'}})) {
		my $s = $str;
		$s =~ s/\@PNAME\@/$k/g;
		my $enc_v = &encode_entities($v);
		# TODO: PVAL must be replaced with P:prop_name and the processed in exp_ent
		# however, this causes problems with HTML-format <BR>s, need ideas
		$s =~ s/\@PVAL\@/$enc_v/g;
		push @accum, $s; 
	}	
	return join $sep, @accum;
}

# expands templates in the style string
# supported template variables:
#   @@ - symbol @
#   @ID@ - entity ID
#   @ID_STRING@ - entity ID formated into string (_ replaced with \n)
#   @P:name@ - the value of property 'name'
sub exp_ent {
	my ($self, $var, $entry) = (@_); # var is a template variable, entry is a relation or entity or section object

	unless ($var) { 
		return '@';
	} elsif ($var eq "ID") {
		return $entry->{'id'};
	} elsif ($var eq "ID_STRING") {
	    my $label = $entry->{'id'};
	    $label =~ s/([a-z0-9]{2,})([A-Z])/$1\\n$2/sgo; # split lines inside camel case words
	    $label =~ s/_/\\n/sgo;               # split line on underscores
	    $label=~ s/\\n(\d)/ $1/g;            # remove new lines after numbers
	    return encode_entities($label);
	} elsif ($var =~ m/^P:(\w+)/o) {
		croak "No properties object for template variable $var in ".$entry->{'id'} unless exists $entry->{'properties'};
		if (exists $entry->{'properties'}->{$1}) {
		  $Text::Wrap::columns=30;
		  $Text::Wrap::separator='<BR/>';
		  # this is the way to properly break lines with HTML encoded characters
		  my $str = wrap("", "", $entry->{'properties'}->{$1});
		  return join '<BR/>', map {encode_entities($_)} split '<BR/>', $str;
		} else { # property does not exists
		  # TODO: create a flag to ignore empty properties
		  #croak "No property named '$1' in ".$entry->{'id'} unless exists $entry->{'properties'}->{$1} if there is flag to stop;
		  return '';
		}
	} elsif ($var eq "SECTION") {
		my $sec = ($entry->{'type'} eq 'sec') ? $entry->{'id'} : $entry->{'sec'};
		$sec =~ s/^.+\|//o; # only keep the last portion of the full section name
	    $sec =~ s/([a-z0-9]{2,})([A-Z])/$1 $2/go; # insert spaces in CamelCase words 
		$sec =~ s/_/ /og;   # replace underscore with spaces
		return $sec;
	} else { 
		croak "Unknown template variable $var";
	}
}

# create a legend and output it into a file
sub write_legend {
	my $self = shift;
	my $fname = shift || croak "Filehandle must be provided";
	my $opts = shift || {}; # second argument is a hash with options
	$opts->{'content'} = 'sect' unless exists $opts->{'content'} && $opts->{'content'};
	# options: 'content' => 'sect,rel' -- output legend for sections and relations

	my $fh = new FileHandle ">$fname" || die "Unable to open '$fname' for writing the legend";

	croak "SOFT object does not contain section legend" unless exists $self->{'sec_legend'};
	
	print $fh "digraph G { \n";
	print $fh "\t".$opts->{'gvopts'}."\n" if exists $opts->{'gvopts'} && $opts->{'gvopts'};
	if ( $opts->{'content'} =~ m/\bsect\b/o ) {
		print $fh "\t/* legend for sections */\n";
		
		my $ck = 0;
		my $pd = -1;
		foreach my $k (sort keys %{$self->{sections}}) {
		  	#print STDERR "$k\n";
			
			my $cd = ($k =~ tr/|//); # current depth
		
		    $k =~ m/([^|]+)$/o;
		    my $label = $1;
		
		    foreach my $l (reverse $cd..$pd) {
		    	print $fh "\t" x $l . "\t}\n";
		  	}
		
			# remove unprintable characters from the section name
			my $sname = $k;
			$sname =~ s/\W/_/go;

		  	print $fh "\n" . "\t" x $cd . "\tsubgraph cluster".$ck++." {\n";
		  	print $fh "\t" x $cd . "\t\tlabel = \"$label\";\n";
		  	print $fh "\t" x $cd . "\t\tlabelloc = t;\n";
		  	print $fh "\t" x $cd . "\t\tstyle = filled;\n";
		  	print $fh "\t" x $cd . "\t\tfillcolor = \"#".$self->{'sec_legend'}->{$k}."\";\n";
		  	print $fh "\t" x $cd . "\t\t$sname [shape=plaintext,fixedsize=t,height=0.1,width=0.1,label=\"\"]"
		  		if keys %{$self->{sections}->{$k}}; 
		
		  	$pd = $cd;
		}
		foreach my $l (reverse 0..$pd) {
			print $fh "\t" x $l . "\t}\n";
		}
		print $fh "\n";

#		foreach my $s (sort keys %{$self->{'sec_legend'}}) {
#			if (%{$self->{'sections'}->{$s}}) {
#				
#				my $sname = $s;
#				$sname =~ s/\W/_/go;
#				
#				my $label = $s;
#				$label =~ s/\|/\\n/og;
#				print $fh "\t$sname [shape=box,label=\"$label\",style=filled,fillcolor=\"#".$self->{'sec_legend'}->{$s}."\"];\n";
#			} else {
#				print $fh "\t/* empty section '$s' omitted */\n";
#			}
#		}
		
	} elsif ( $opts->{'content'} =~ m/\brel\b/o ) {
		print $fh "\t/* legend for relations */\n";
		print $fh "\tuninplemented; \n";
	}
	print $fh "}\n";
	
	$fh->close();
}

# return the counts of the type of entities in the SOFT structure
sub counts {
	my $self = shift;
	
	my %c = ( 
		'relations' => scalar @{$self->{'rel'}}, 
		'entities' => scalar keys %{$self->{'ent'}}, 
		'sections' => scalar keys %{$self->{'sections'}}, 
	);
	return wantarray ? %c : "relation_types=".$c{'relations'}." entities=".$c{'entities'}." sections=".$c{'sections'};
}

# dumps the content of the SOFT object on the specified filehandle
# arguments
#   filename to write into ('-' for STDOUT)
#   a list of options of what to dump (ent[ities], rel[ations], sty[les])
sub dump {
  my $self = shift;
  my $fname = shift || croak "File name must be provided";
	
  my $fh = undef;
  if ($fname eq '-') {
    $fh = \*STDOUT;
  } else {
    $fh = new FileHandle ">$fname" || die "Unable to open '$fname' for writing";
  }
  binmode $fh, ':encoding(UTF-8)';

  if (@_) {
    foreach (@_) {
      print $fh Dumper($self) if /^all$/o;
      print $fh Dumper($self->{'ent'}) if /^ent(?:ities)?$/o;
      print $fh Dumper($self->{'rel'}) if /^rel(?:ations)?/o;
      print $fh Dumper($self->{'styles'}) if /^sty(?:les)?/o;
    }
  } else {
      print $fh Dumper($self);
  }

  $fh->close() unless $fname eq '-';
}

# list the entities in the soft object 
sub list {
	my ($self, $fname, $opts) = (@_);
	
	# opts should include separator, format)
	$opts = {} unless $opts;
	$opts->{'sep'} = "\n" unless exists $opts->{'sep'};
	
	# FIXME: factor out file open into SOFT::Utils
 	my $fh = undef;
	if ($fname eq '-') {
    	$fh = \*STDOUT;
  	} else {
	    $fh = new FileHandle ">$fname" || die "Unable to open '$fname' for writing";
  	}
  	binmode $fh, ':encoding(UTF-8)';

	foreach ($self->all()) {
		# TODO: this all has to be changed to support format string
		m/^cat:(.*)$/ || next;
		print $1.$opts->{'sep'};
	}
}

### ontological functions

# finds entities that are related to the specified entities through specified relation type
#   the function will find all triplets that satisfy provided arguments ($from, $rel, $to)
#   arguments are understood as cat:ent1 -rel-> cat:ent2
#   'from' and 'to' arguments may be either entity names or *references* to the arrays of entity names
#   one of 'from' and 'to' may be a question mark, if none is a question mark the existence of the provided relation is tested
#   returns an list of relation objects that satisfy the condition 
#   existence of entities is not checked
sub find {
	my ($self, $from, $rel, $to) = (@_);

	my @r = ();
	
	confess "One or more of (from, rel, to) is not defined in find function"
		unless defined $from && defined $rel && defined $to;
	confess "Two variables in find function is not supported" 
		if ($from eq '?' && $to eq '?');
	
	if ( $from eq '?' ) {
		$to = [$to] unless ref $to;
		my %idx = map { $_ => 1 } @$to;
		@r = map {$_->{'from'}} 
			grep { exists $idx{$_->{'to'}} && $_->{'id'} eq $rel } 
				@{$self->{'rel'}};
	} elsif ($to eq '?') { 
		$from = [$from] unless ref $from;
		my %idx = map { $_ => 1 } @$from;
		@r = map {$_->{'to'}} 
			grep { exists $idx{$_->{'from'}} && $_->{'id'} eq $rel } 
				@{$self->{'rel'}};
	} else { 
		confess "No variables were specified in find function"
	}
	
	return @r;
}

# finds entities satisfying the relation by traversing a chain of relations
# satisfying the condition (useful to traverse DAGs)
#   arguments exactly the same as in find
sub find_traverse {
	my ($self, $from, $rel, $to) = (@_);

	my %found = ();

	if (ref $from) {
		%found = map { $_ => 1 } @$from;
	} elsif (ref $to) {
		%found = map { $_ => 1 } @$to;
	} else {
		croak "No variable specified in find function";
	}
	
	my $sz;
	
	do {
		$sz = scalar keys %found;
		$from = [keys %found] unless $from eq '?';
		$to   = [keys %found] unless $to eq '?';
		%found = ( %found, map { $_ => 1 } $self->find( $from, $rel, $to ) ) ;
	} while ( scalar keys %found > $sz );
	
	return keys %found;	
}

# check (or filter an array) if an entity is a leaf given the relation
# leaf is understood as: cat:leaf -relation-> cat:not_leaf
# arguments:
#   relation to check
#   a list of entities to check
# returns a list of entities or empty list
sub is_leaf {
	my $self = shift;
	my $rel  = shift;
	
	my @found = ();
	foreach (@_) {
		push @found, $_ unless $self->find( '?', $rel, $_);
	}
	
	return @found;
}

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SOFT;

    my $softh = SOFT->new();
    $softh->parse_soft(STDIN);
    $softh->write_gv(STDOUT)
    ...

=head1 AUTHOR

"Alex Sorokine", C<< <"SorokinA@ornl.gov"> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-soft at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SOFT>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SOFT


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SOFT>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SOFT>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SOFT>

=item * Search CPAN

L<http://search.cpan.org/dist/SOFT/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2010 Alexandre Sorokine, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of SOFT.pm

