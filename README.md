# Simple Ontology FormaT (SOFT)

SOFT is a human-readable and human-editable ontology format.  SOFT
files can be created and modified using basic text editor like vi or
emacs and processed using common command-line Unix tools like grep or
diff.  SOFT supports representation of ontologies as triples similar
to RDF and n3 formats.  Support for time-indexed relations is in the
development.  In addition to triples, SOFT supports storing of entity
properties in CSV format or relational database.

SOFT ontologies can be rendered as diagrams using Graphviz layout
engine (http://graphviz.org) with support for advanced styles.
Currently software support for SOFT is implemented as perl module
SOFT.pm.  Such functionality as parsing, validating, and writing of
the SOFT and its associated files is available.  Also ontologies in
SOFT format can be converted into Graphviz gv files for diagram
rendering or into plain text for use in other programs.

## SOFT Specification in 5 Lines
```

# Simple Ontology FormaT (*.soft)
#
# [section]
# [[subsection]]
# entity_type:enity_name -relation_name-> entity_type:enity_name 
```
## SOFT Example 
```

# this is a comment (ignored)
    
[Healthy_Food]
cat:apples -subcat-> cat:fruits
cat:oranges -subcat-> cat:fruits
```
and it renders in

![SOFT Example 1](SOFT/wiki/example1.png)

# SOFT Data Model

* relations in ontologies are represented as triples using the
  following syntax:
```
cat:category1 -relation-> cat:category2
```

* [NOT IMPLEMENTED] relations can be time-indexed:
```
cat:category1 -relation-> cat:category2 @time-interval
```

* there are two basic types of entities in SOFT:
 * ```cat:``` categories
 * ```inst:``` instances

* SOFT file can be divided into nested sections.  Sections are
  designated by square brackets:
```
[Section 1]
[[Section 1.1]]
```
 * [NOT IMPLEMENTED] sections also subdivide SOFT files into 
   namespaces 

* ontology entities can be associated with properties that are stored
  in CSV files or relational databases