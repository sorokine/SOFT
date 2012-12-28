Simple Ontology FormaT (SOFT)
=============================

SOFT is a human-readable and human-editable ontology format.  SOFT
files can be created and modified using basic text editor like vi or
emacs and processed using common command-line Unix tools like grep or
diff.  SOFT supports representation of ontologies as triples similar
to RDF and n3 formats.  Support for time-indexed relations is in the
development.  In addition to triples, SOFT supports storing of entity
properties in CSV format or relational database and rendering diagrams
by way of graphviz (http://graphviz.org).

For more information visit SOFT web site at http://sorokine.github.com/SOFT

Quick Installation Instruction
==============================

Requirements
------------

1.  Unix-like system (Linux, OSX, or cygwin on Windows)
2.  Perl 5 and access to CPAN
3.  graphviz from http://graphviz.org (for diagrams)

Installation Steps
------------------
1.  Download SOFT distribution or clone SOFT repository from Github
2.  cd SOFT/SOFT
3.  run standard Perl module installation procedure:
  1.  perl Makefile.PL
  2.  make
  3.  make install
4.  verify installation by launching ```soft2gv.pl -h```

